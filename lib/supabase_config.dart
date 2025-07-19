import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  // Load configuration from environment variables
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'YOUR_SUPABASE_URL_HERE';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? 'YOUR_SUPABASE_ANON_KEY_HERE';

  // Dynamic redirect URL based on environment
  static String get redirectUrl {
    if (kIsWeb) {
      // For web builds, use the production URL or fallback to localhost
      final productionUrl = dotenv.env['PRODUCTION_URL'];
      if (productionUrl != null && productionUrl.isNotEmpty) {
        return '$productionUrl/';
      }
      
      final vercelUrl = dotenv.env['VERCEL_URL'];
      if (vercelUrl != null && vercelUrl.isNotEmpty) {
        return '$vercelUrl/';
      }
      
      return 'http://localhost:3000/'; // Fallback for local development
    } else if (defaultTargetPlatform == TargetPlatform.linux ||
               defaultTargetPlatform == TargetPlatform.macOS ||
               defaultTargetPlatform == TargetPlatform.windows) {
      // For desktop platforms, we'll handle this differently in the auth service
      return deepLinkScheme;
    }
    // For mobile apps, use deep link scheme  
    return 'me.pi22by7.flowrite://login-callback';
  }
  
  // Callback URL scheme for flutter_web_auth_2 on desktop
  static String get desktopCallbackScheme {
    return 'http'; // Use http scheme for localhost
  }

  // Google OAuth Client IDs for different platforms
  static String get webClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ??
      'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  static String get androidClientId =>
      dotenv.env['GOOGLE_ANDROID_CLIENT_ID'] ??
      'YOUR_ANDROID_CLIENT_ID.apps.googleusercontent.com';

  static String get iosClientId =>
      dotenv.env['GOOGLE_IOS_CLIENT_ID'] ??
      'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com';

  // Deep link scheme for desktop OAuth callback
  static String get deepLinkScheme =>
      dotenv.env['DEEP_LINK_SCHEME'] ?? 'me.pi22by7.flowrite://login-callback';
}
