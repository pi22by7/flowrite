import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Load configuration from environment variables
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'YOUR_SUPABASE_URL_HERE';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? 'YOUR_SUPABASE_ANON_KEY_HERE';

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
