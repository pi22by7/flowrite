import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
        defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<AuthResponse> _webBasedGoogleSignIn() async {
    if (kIsWeb) {
      // For web platforms, use Supabase OAuth directly
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: SupabaseConfig.redirectUrl,
        authScreenLaunchMode: LaunchMode.platformDefault,
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
    } else {
      // For desktop platforms, use manual OAuth flow
      return await _manualDesktopOAuth();
    }
  }

  Future<AuthResponse> _manualDesktopOAuth() async {
    debugPrint('Starting desktop OAuth flow with temporary server...');

    // Start a temporary HTTP server on localhost:3000
    HttpServer? server;
    Completer<String> callbackCompleter = Completer<String>();

    try {
      server = await HttpServer.bind('localhost', 3000);
      debugPrint('Started temporary server on localhost:3000');

      // Listen for incoming requests
      server.listen((HttpRequest request) async {
        final uri = request.uri;
        debugPrint('Received callback: $uri');

        // Handle CORS preflight requests
        if (request.method == 'OPTIONS') {
          request.response
            ..statusCode = 200
            ..headers.set('Access-Control-Allow-Origin', '*')
            ..headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            ..headers.set('Access-Control-Allow-Headers', 'Content-Type');
          await request.response.close();
          return;
        }

        // Handle the callback URL with tokens
        if (request.method == 'GET' && request.uri.path == '/auth/callback') {
          final encodedUrl = request.uri.queryParameters['url'];
          if (encodedUrl != null) {
            final fullUrl = Uri.decodeComponent(encodedUrl);
            debugPrint('Received full callback URL: $fullUrl');

            // Send success response
            request.response
              ..statusCode = 200
              ..headers.set('Content-Type', 'text/html')
              ..write('''
                <html>
                  <head><title>Authentication Complete</title></head>
                  <body>
                    <h1>Authentication Successful!</h1>
                    <p>You can close this window and return to the app.</p>
                    <script>window.close();</script>
                  </body>
                </html>
              ''');
            await request.response.close();

            if (!callbackCompleter.isCompleted) {
              callbackCompleter.complete(fullUrl);
            }
          }
        } else if (request.uri.path == '/' && !callbackCompleter.isCompleted) {
          // Send initial page with JavaScript to capture tokens
          request.response
            ..statusCode = 200
            ..headers.set('Content-Type', 'text/html')
            ..write('''
              <html>
                <head><title>Authentication Complete</title></head>
                <body>
                  <h1>Authentication Successful!</h1>
                  <p>You can close this window and return to the app.</p>
                  <script>
                    // Send the full URL with fragment to the server via GET request
                    if (window.location.hash) {
                      const encodedUrl = encodeURIComponent(window.location.href);
                      window.location.href = '/auth/callback?url=' + encodedUrl;
                    } else {
                      window.close();
                    }
                  </script>
                </body>
              </html>
            ''');
          await request.response.close();
          debugPrint('Sent initial page, waiting for JavaScript redirect...');
        }
      });

      // Generate the OAuth URL with localhost redirect
      final oauthUrl = Uri.https(
          Uri.parse(SupabaseConfig.supabaseUrl).host, '/auth/v1/authorize', {
        'provider': 'google',
        'redirect_to': 'http://localhost:3000/',
      });

      debugPrint('OAuth URL: $oauthUrl');

      // Open the browser
      if (await canLaunchUrl(oauthUrl)) {
        await launchUrl(oauthUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch OAuth URL');
      }

      // Wait for the callback (with timeout)
      final callbackUrl = await callbackCompleter.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception(
            'OAuth timeout - authentication callback was not received'),
      );

      debugPrint('Received OAuth callback: $callbackUrl');

      // Parse the callback URL for auth tokens
      final uri = Uri.parse(callbackUrl);
      final fragment = uri.fragment;

      if (fragment.isNotEmpty) {
        // Handle fragment-based tokens (implicit flow)
        final params = Uri.splitQueryString(fragment);
        final accessToken = params['access_token'];

        if (accessToken != null) {
          debugPrint('Found tokens in fragment, using setSession...');
          
          // Extract refresh token
          final refreshToken = params['refresh_token'];
          
          if (refreshToken != null) {
            debugPrint('Setting session with refresh token...');
            // Use setSession with the refresh token
            final response = await _supabase.auth.setSession(refreshToken);
            
            return response;
          } else {
            throw Exception('Refresh token not found in OAuth response');
          }
        }
      }

      // Handle query parameter-based tokens (authorization code flow)
      final code = uri.queryParameters['code'];
      if (code != null) {
        debugPrint('Found authorization code, exchanging for tokens...');
        final response = await _supabase.auth.exchangeCodeForSession(code);
        return AuthResponse(
          session: response.session,
          user: response.session.user,
        );
      }

      throw Exception('No valid auth data found in callback URL');
    } catch (e) {
      debugPrint('Desktop OAuth failed: $e');
      rethrow;
    } finally {
      // Always close the server
      await server?.close();
      debugPrint('Temporary server closed');
    }
  }

  Future<AuthResponse> _nativeGoogleSignIn() async {
    debugPrint('Starting native Google Sign-In...');
    debugPrint('Platform: $defaultTargetPlatform');
    debugPrint('Web Client ID: ${SupabaseConfig.webClientId}');
    debugPrint('Android Client ID: ${SupabaseConfig.androidClientId}');
    debugPrint('iOS Client ID: ${SupabaseConfig.iosClientId}');

    final GoogleSignIn googleSignIn = GoogleSignIn.instance;

    // Initialize with proper client IDs (required in 7.x)
    await googleSignIn.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? SupabaseConfig.iosClientId
          : defaultTargetPlatform == TargetPlatform.android
              ? SupabaseConfig.androidClientId
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
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

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
