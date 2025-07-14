import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_cloud_sync_service.dart';

class SyncProvider extends ChangeNotifier {
  final SupabaseAuthService _auth = SupabaseAuthService();
  final SupabaseCloudSyncService _cloudSync = SupabaseCloudSyncService();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.isSignedIn;
  String get userEmail => _auth.userEmail;
  Timer? _syncTimer;

  SyncProvider() {
    // Check for pending syncs every minute
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      checkPendingSyncs();
    });
  }

  Stream<AuthState> get authStateChanges => _auth.authStateChanges;

  Future<void> checkPendingSyncs() async {
    if (!isSignedIn) {
      debugPrint('User not signed in, skipping cloud sync');
      return;
    }

    try {
      _isSyncing = true;
      notifyListeners();

      // Check if online before syncing
      final isOnline = await _cloudSync.isOnline;
      if (!isOnline) {
        debugPrint('Device is offline, skipping cloud sync');
        return;
      }

      // Sync pending changes
      await _cloudSync.syncPendingChanges();
      debugPrint('Pending changes synced successfully');
    } catch (e) {
      debugPrint('Error checking pending syncs: $e');
      rethrow; // Re-throw to let caller handle the error appropriately
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
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
      await _cloudSync.syncPendingChanges();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
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

      await _auth.signOut();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
