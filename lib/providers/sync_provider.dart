import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/resilient_sync_service.dart';
import '../models/sync_operation.dart';

class SyncProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();
  final ResilientSyncService _resilientSync = ResilientSyncService();

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
    // Listen to sync status changes
    _statusSubscription = _resilientSync.statusStream.listen((status) {
      _syncStatus = status;
      _isSyncing = status == SyncStatus.syncing;
      notifyListeners();
    });

    // Check for pending syncs every 2 minutes (increased from 1)
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      checkPendingSyncs();
    });
  }

  Stream<AuthState> get authStateChanges => _auth.authStateChanges;

  /// Check and process pending syncs with resilience
  Future<void> checkPendingSyncs() async {
    if (!isSignedIn) {
      debugPrint('⚠️ User not signed in, skipping cloud sync');
      return;
    }

    try {
      // Use resilient sync service which handles retries and conflicts
      await _resilientSync.processSyncQueue();
      debugPrint('✅ Pending syncs processed');
    } catch (e) {
      // Don't rethrow - resilient sync handles errors gracefully
      debugPrint('⚠️ Error processing pending syncs: $e');
    }
  }

  /// Get sync queue statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    return await _resilientSync.getSyncStats();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _statusSubscription?.cancel();
    _resilientSync.dispose();
    super.dispose();
  }

  Future<bool> signInWithGoogle() async {
    try {
      _isSyncing = true;
      notifyListeners();

      // Use the auth service to sign in
      final response = await _auth.signInWithGoogle();

      if (response?.user == null) return false;

      // Initial sync after sign in using resilient service
      await _resilientSync.processSyncQueue();

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
      await _resilientSync.clearSyncData();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
