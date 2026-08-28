import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/sync_backend.dart';
import '../services/backends/supabase_sync_backend.dart';
import '../services/backends/webdav_sync_backend.dart';
import '../models/writing_file.dart';
import '../models/sync_operation.dart';
import 'settings_provider.dart';

SyncBackend _buildBackend(SyncBackendType type) {
  switch (type) {
    case SyncBackendType.webdav:
      return WebDavSyncBackend();
    case SyncBackendType.supabase:
    case SyncBackendType.none:
    case SyncBackendType.icloud:
      // `none`/`icloud` fall back to Supabase until iCloud (Phase 4) exists;
      // `none` still needs *a* backend since callers assume _backend is non-null.
      return SupabaseSyncBackend();
  }
}

class SyncProvider extends ChangeNotifier {
  static const String _syncBackendTypeKey = 'syncBackendType';

  final AuthService _auth = AuthService();
  // Not final: reassigned when the user switches sync backends in Settings.
  // ignore: prefer_final_fields
  SyncBackend _backend = SupabaseSyncBackend();
  SyncBackendType _backendType = SyncBackendType.supabase;
  SyncBackendType get backendType => _backendType;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncStatus _syncStatus = SyncStatus.idle;
  SyncStatus get syncStatus => _syncStatus;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.isSignedIn;
  String get userEmail => _auth.userEmail;
  Timer? _syncTimer;
  StreamSubscription<SyncStatus>? _statusSubscription;

  SyncProvider() {
    _listenToBackendStatus();
    _restorePersistedBackend();

    // Check for pending syncs every 2 minutes (increased from 1)
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      checkPendingSyncs();
    });
  }

  Future<void> _restorePersistedBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final persisted = SyncBackendType.values.firstWhere(
      (t) => t.name == prefs.getString(_syncBackendTypeKey),
      orElse: () => SyncBackendType.supabase,
    );
    if (persisted != SyncBackendType.supabase) {
      await switchBackend(persisted);
    }
  }

  /// Switches to a different sync backend: clears the outgoing backend's
  /// local sync bookkeeping, disposes it, and rebuilds `_backend` for [type].
  /// Remote data is not migrated between backends.
  Future<void> switchBackend(SyncBackendType type) async {
    if (type == _backendType) return;

    await _backend.clearSyncData();
    _statusSubscription?.cancel();
    _backend.dispose();

    _backend = _buildBackend(type);
    _backendType = type;
    _listenToBackendStatus();

    notifyListeners();
  }

  void _listenToBackendStatus() {
    _statusSubscription = _backend.statusStream.listen((status) {
      _syncStatus = status;
      _isSyncing = status == SyncStatus.syncing;
      notifyListeners();
    });
  }

  Stream<AuthState> get authStateChanges => _auth.authStateChanges;

  /// Files known to the current backend (e.g. Supabase realtime stream).
  Stream<List<WritingFile>> getFilesStream() => _backend.getFilesStream();

  /// Check and process pending syncs with resilience
  Future<void> checkPendingSyncs() async {
    if (!_backend.isSignedIn) {
      debugPrint('⚠️ Backend not configured, skipping cloud sync');
      return;
    }

    try {
      await _backend.processSyncQueue();
      debugPrint('✅ Pending syncs processed');
    } catch (e) {
      // Don't rethrow - backend handles errors gracefully
      debugPrint('⚠️ Error processing pending syncs: $e');
    }
  }

  /// Get sync queue statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    return await _backend.getSyncStats();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _statusSubscription?.cancel();
    _backend.dispose();
    super.dispose();
  }

  Future<bool> signInWithGoogle() async {
    try {
      _isSyncing = true;
      notifyListeners();

      // Use the auth service to sign in
      final response = await _auth.signInWithGoogle();

      if (response?.user == null) return false;

      // Initial sync after sign in
      await _backend.processSyncQueue();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error signing in with Google: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      _isSyncing = true;
      notifyListeners();

      // Sign out and clear sync data
      await _auth.signOut();
      await _backend.clearSyncData();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
