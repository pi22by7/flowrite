import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';

class SupabaseAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
  bool get isSignedIn => currentUser != null;
  String get userEmail => currentUser?.email ?? '';
  String get userId => currentUser?.id ?? '';

  Future<AuthResponse?> signInWithGoogle() async {
    try {
      debugPrint('Starting Google Sign-In process...');

      if (_isDesktopOrWeb()) {
        debugPrint('Using web-based Google Sign-In');
        // Use web-based OAuth for desktop platforms and web
        return await _webBasedGoogleSignIn();
      } else {
        debugPrint('Using native Google Sign-In');
        // Use native Google Sign-In for mobile platforms
        return await _nativeGoogleSignIn();
      }
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      debugPrint('Error type: ${e.runtimeType}');

      // Re-throw the exception so the UI can handle it properly
      // instead of just returning null
      rethrow;
    }
  }

  bool _isDesktopOrWeb() {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<AuthResponse> _webBasedGoogleSignIn() async {
    final response = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? SupabaseConfig.redirectUrl : SupabaseConfig.deepLinkScheme,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );

    if (!response) {
      throw Exception('OAuth sign-in was cancelled or failed');
    }

    // Wait for the auth state change to get the session
    await for (final authState in _supabase.auth.onAuthStateChange) {
      if (authState.session != null) {
        return AuthResponse(
            session: authState.session, user: authState.session!.user);
      }
    }

    throw Exception('Sign-in completed but no session was created');
  }

  Future<AuthResponse> _nativeGoogleSignIn() async {
    debugPrint('Starting native Google Sign-In...');
    debugPrint('Platform: $defaultTargetPlatform');
    debugPrint('Web Client ID: ${SupabaseConfig.webClientId}');
    debugPrint('iOS Client ID: ${SupabaseConfig.iosClientId}');

    final GoogleSignIn googleSignIn = GoogleSignIn.instance;

    // Initialize with proper client IDs (required in 7.x)
    await googleSignIn.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? SupabaseConfig.iosClientId
          : null,
      serverClientId: SupabaseConfig.webClientId,
    );

    // Check if authenticate is supported on this platform
    if (!googleSignIn.supportsAuthenticate()) {
      throw Exception('This platform does not support authenticate method');
    }

    debugPrint('Calling googleSignIn.authenticate()...');
    GoogleSignInAccount googleUser;
    try {
      googleUser = await googleSignIn.authenticate();
    } catch (e) {
      debugPrint('Google authenticate failed: $e');
      throw Exception('Google sign-in was cancelled by user or failed: $e');
    }

    debugPrint('Google user authenticated: ${googleUser.email}');

    // Get the authentication details from the signed-in user
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    debugPrint('Google auth tokens retrieved');
    debugPrint('ID Token length: ${googleAuth.idToken?.length ?? 0}');

    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw Exception('Failed to get Google ID token');
    }

    debugPrint('Attempting Supabase sign-in with ID token...');

    // Use the ID token with Supabase - for Google OAuth, we typically only need the ID token
    try {
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      debugPrint('Supabase sign-in successful');
      debugPrint('User ID: ${response.user?.id}');
      debugPrint('User email: ${response.user?.email}');

      return response;
    } catch (e) {
      debugPrint('Supabase sign-in failed: $e');
      debugPrint('Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      // Sign out from Google on mobile platforms
      if (!_isDesktopOrWeb()) {
        await GoogleSignIn.instance.disconnect();
      }

      // Sign out from Supabase
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Error during sign out: $e');
      // Still try to sign out from Supabase even if Google sign out fails
      await _supabase.auth.signOut();
    }
  }

  Future<AuthResponse> signInWithEmailPassword(
      String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmailPassword(
      String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }
}
