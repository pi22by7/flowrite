import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../cloud_config.dart';
import '../services/auth_service.dart';
import '../services/sync_backend.dart';
import '../services/backends/local_sync_backend.dart';
import '../services/backends/supabase_sync_backend.dart';
import '../services/backends/webdav_sync_backend.dart';
import '../services/storage_service.dart';
import '../services/webdav_config_service.dart';
import '../services/sync_queue_service.dart';
import '../models/writing_file.dart';
import '../models/sync_operation.dart';
import 'settings_provider.dart';

class SyncProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AuthService _auth = AuthService();
  final WebDavConfigService _webDavConfigService;
  SyncBackend _backend = LocalSyncBackend();
  SyncBackendType _backendType = SyncBackendType.none;
  SyncBackendType get backendType => _backendType;
  SyncBackend get activeBackend => _backend;
  bool get supabaseAvailable => SupabaseConfig.isConfigured;
  bool _disposed = false;
  int _revision = 0;
  int get revision => _revision;
  late final Future<void> ready;
  Future<void>? _processing;
  final _switchLock = Lock();
  bool _switching = false;
  Timer? _syncTimer;
  Timer? _saveTimer;
  StreamSubscription<SyncStatus>? _statusSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  SyncStatus _syncStatus = SyncStatus.idle;
  SyncStatus get syncStatus => _syncStatus;
  bool get isSyncing => _syncStatus == SyncStatus.syncing;
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.isSignedIn;
  String get userEmail => _auth.userEmail;
  bool get isCloudConfigured =>
      _backendType != SyncBackendType.none && _backend.isSignedIn;
  Stream<AuthState> get authStateChanges => _auth.authStateChanges;

  SyncProvider({WebDavConfigService? webDavConfigService})
      : _webDavConfigService = webDavConfigService ?? WebDavConfigService() {
    WidgetsBinding.instance.addObserver(this);
    ready = _restorePersistedBackend();
    _syncTimer =
        Timer.periodic(const Duration(minutes: 2), (_) => checkPendingSyncs());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) scheduleSync();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _restorePersistedBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final type = SyncBackendType.values.firstWhere(
        (t) => t.name == prefs.getString('syncBackendType'),
        orElse: () => SyncBackendType.none);
    if (type == SyncBackendType.supabase && !supabaseAvailable) return;
    try {
      await switchBackend(type, uploadExisting: false);
    } catch (e) {
      debugPrint('Could not restore sync backend: $e');
      _syncStatus = SyncStatus.error;
      _changed();
    }
  }

  Future<void> _changeBackend(Future<void> Function() action) =>
      _switchLock.synchronized(() async {
        _switching = true;
        _saveTimer?.cancel();
        try {
          await action();
        } finally {
          _switching = false;
        }
      });

  Future<void> switchBackend(SyncBackendType type,
          {bool uploadExisting = true}) =>
      _changeBackend(
          () => _switchBackend(type, uploadExisting: uploadExisting));

  Future<void> _switchBackend(SyncBackendType type,
      {bool uploadExisting = true, bool force = false}) async {
    if (type == SyncBackendType.icloud) {
      throw UnsupportedError('iCloud is not implemented');
    }
    if (type == _backendType && !force) return;
    if (type == SyncBackendType.supabase) await AuthService.initialize();
    if (_disposed) return;
    // Let an in-flight upload finish before disposing its backend.
    await _processing;
    await _statusSubscription?.cancel();
    await _authSubscription?.cancel();
    _backend.dispose();
    _backend = switch (type) {
      SyncBackendType.webdav =>
        WebDavSyncBackend(configService: _webDavConfigService),
      SyncBackendType.supabase => SupabaseSyncBackend(),
      _ => LocalSyncBackend(),
    };
    _backendType = type;
    _auth.setAutoRefresh(type == SyncBackendType.supabase);
    _syncStatus = SyncStatus.idle;
    _statusSubscription = _backend.statusStream.listen((status) {
      _syncStatus = status;
      _changed();
    });
    if (type == SyncBackendType.supabase) {
      _authSubscription = _auth.authStateChanges.listen((_) {
        _revision++;
        _changed();
        scheduleSync();
      });
    }
    await (await SharedPreferences.getInstance())
        .setString('syncBackendType', type.name);
    if (uploadExisting && type != SyncBackendType.none) await queueAllFiles();
    _revision++;
    _changed();
    scheduleSync();
  }

  Future<void> configureWebDav(WebDavConfig config) async {
    await ready;
    await _changeBackend(() async {
      await _processing;
      await _webDavConfigService.saveConfig(config);
      await _switchBackend(SyncBackendType.webdav,
          uploadExisting: false, force: true);
      await queueAllFiles();
      _revision++;
      _changed();
      scheduleSync();
    });
  }

  /// Seed the newly selected server with all local documents, including deletion
  /// records. Existing pending operations are retained, rather than reset.
  Future<void> queueAllFiles() async {
    final storage = StorageService.create();
    for (final id in await storage.getAllFileIds()) {
      await storage.updateMetadata(id, (metadata) {
        metadata['id'] ??= id;
        metadata['name'] ??= id;
        metadata['lastModified'] ??= DateTime.now().toUtc().toIso8601String();
        metadata['pendingSync'] ??= SyncQueueService.newOperation(
                id,
                metadata['deleted'] == true
                    ? SyncOperationType.delete
                    : SyncOperationType.update)
            .toJson();
      });
    }
  }

  void scheduleSync() {
    if (_disposed || _backendType == SyncBackendType.none) return;
    _saveTimer?.cancel();
    _saveTimer =
        Timer(const Duration(milliseconds: 600), () => checkPendingSyncs());
  }

  Stream<List<WritingFile>> getFilesStream() => _backend.getFilesStream();

  Future<void> checkPendingSyncs({bool retryFailed = false}) async {
    await ready;
    if (_disposed || _switching || _backendType == SyncBackendType.none) return;
    if (_processing != null) return _processing;
    final backend = _backend;
    _processing = () async {
      if (retryFailed) await SyncQueueService().resetRetries();
      try {
        await backend.processSyncQueue();
      } catch (e) {
        debugPrint('Background sync failed: $e');
      }
      _revision++;
      _changed();
    }();
    try {
      await _processing;
    } finally {
      _processing = null;
    }
  }

  Future<Map<String, dynamic>> getSyncStats() =>
      SyncQueueService().getQueueStats();

  Future<bool> signInWithGoogle() async {
    if (_backendType != SyncBackendType.supabase) return false;
    try {
      final response = await _auth.signInWithGoogle();
      if (response?.user == null) return false;
      await queueAllFiles();
      scheduleSync();
      return true;
    } catch (e) {
      debugPrint('Sign-in failed: $e');
      return false;
    } finally {
      _revision++;
      _changed();
    }
  }

  Future<void> signOut() async {
    // Disable processing before ending the session; never discard unsent edits.
    await switchBackend(SyncBackendType.none);
    await _auth.signOut();
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _saveTimer?.cancel();
    _authSubscription?.cancel();
    _statusSubscription?.cancel();
    final processing = _processing;
    if (processing == null) {
      _backend.dispose();
    } else {
      final backend = _backend;
      unawaited(processing.whenComplete(backend.dispose));
    }
    super.dispose();
  }
}
