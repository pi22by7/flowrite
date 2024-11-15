// lib/providers/sync_provider.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../services/cloud_sync_service.dart';

class SyncProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final CloudSyncService _cloudSync = CloudSyncService();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  String get userEmail => currentUser?.email ?? '';
  Timer? _syncTimer;

  SyncProvider() {
    // Check for pending syncs every minute
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      checkPendingSyncs();
    });
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> checkPendingSyncs() async {
    if (!isSignedIn) return;

    try {
      _isSyncing = true;
      notifyListeners();

      // Sync pending changes
      await _cloudSync.syncPendingChanges();

    } catch (e) {
      debugPrint('Error checking pending syncs: $e');
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

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) return false;

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Initial sync after sign in
      if (userCredential.user != null) {
        await _cloudSync.syncPendingChanges();
      }

      notifyListeners();
      return userCredential.user != null;
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

      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
