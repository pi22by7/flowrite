import 'package:flowrite/providers/settings_provider.dart';
import 'package:flowrite/utils/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/sync_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'cloud_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress debug logs in production
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Load environment variables
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        // Just show a simple loading indicator if theme not ready (rare)
        if (!themeProvider.isInitialized) {
          return MaterialApp(
            title: 'Flowrite',
            theme: ThemeData.light(),
            home: const Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        
        return MaterialApp(
          title: 'Flowrite',
          themeMode: themeProvider.materialThemeMode,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          home: FlowriteAnimations.fadeIn(
            duration: FlowriteDurations.standard,
            curve: FlowriteCurves.gentleReveal,
            child: const HomeScreen(),
          ),
        );
      },
    );
  }
}
