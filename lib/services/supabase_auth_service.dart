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
      if (_isDesktopOrWeb()) {
        // Use web-based OAuth for desktop platforms and web
        return await _webBasedGoogleSignIn();
      } else {
        // Use native Google Sign-In for mobile platforms
        return await _nativeGoogleSignIn();
      }
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return null;
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
      redirectTo: kIsWeb ? null : SupabaseConfig.deepLinkScheme,
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
    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? SupabaseConfig.iosClientId
          : null,
      serverClientId: SupabaseConfig.webClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in was cancelled by user');
    }

    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null) {
      throw Exception('No Access Token found from Google');
    }
    if (idToken == null) {
      throw Exception('No ID Token found from Google');
    }

    return await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut() async {
    try {
      // Sign out from Google on mobile platforms
      if (!_isDesktopOrWeb()) {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: defaultTargetPlatform == TargetPlatform.iOS
              ? SupabaseConfig.iosClientId
              : null,
          serverClientId: SupabaseConfig.webClientId,
        );
        await googleSignIn.signOut();
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
