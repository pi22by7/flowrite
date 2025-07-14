import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

enum AppThemeMode { system, light, dark }

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.system;
  bool _useDynamicColors = true;
  ThemeData? _dynamicLightTheme;
  ThemeData? _dynamicDarkTheme;

  ThemeProvider() {
    // Load dynamic themes on initialization if dynamic colors are enabled
    if (_useDynamicColors) {
      _loadDynamicThemes();
    }
  }

  AppThemeMode get themeMode => _themeMode;
  bool get useDynamicColors => _useDynamicColors;
  
  // Legacy getter for compatibility
  bool get isDarkMode => _themeMode == AppThemeMode.dark;

  void toggleTheme() {
    switch (_themeMode) {
      case AppThemeMode.system:
        _themeMode = AppThemeMode.light;
        break;
      case AppThemeMode.light:
        _themeMode = AppThemeMode.dark;
        break;
      case AppThemeMode.dark:
        _themeMode = AppThemeMode.system;
        break;
    }
    notifyListeners();
  }

  void setThemeMode(AppThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void toggleDynamicColors() {
    _useDynamicColors = !_useDynamicColors;
    if (_useDynamicColors) {
      _loadDynamicThemes();
    }
    notifyListeners();
  }

  ThemeData get currentTheme {
    return getThemeForBrightness(_getEffectiveBrightness());
  }
  
  ThemeData get lightTheme {
    return getThemeForBrightness(Brightness.light);
  }
  
  ThemeData get darkTheme {
    return getThemeForBrightness(Brightness.dark);
  }
  
  ThemeMode get materialThemeMode {
    switch (_themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }
  
  ThemeData getThemeForBrightness(Brightness brightness) {
    if (_useDynamicColors) {
      if (brightness == Brightness.dark && _dynamicDarkTheme != null) {
        return _dynamicDarkTheme!;
      } else if (brightness == Brightness.light && _dynamicLightTheme != null) {
        return _dynamicLightTheme!;
      }
    }
    return brightness == Brightness.dark ? _darkTheme : _lightTheme;
  }
  
  Brightness _getEffectiveBrightness() {
    switch (_themeMode) {
      case AppThemeMode.system:
        // This will be overridden by system theme in MaterialApp
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
    }
  }

  Future<void> _loadDynamicThemes() async {
    try {
      _dynamicLightTheme = await createDynamicTheme(Brightness.light);
      _dynamicDarkTheme = await createDynamicTheme(Brightness.dark);
      notifyListeners();
    } catch (e) {
      // Fallback to regular themes if dynamic colors fail
      _useDynamicColors = false;
    }
  }

  static final _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6246EA), // Deep Purple
      brightness: Brightness.light,
    ),
    // Material 3 Expressive Typography
    textTheme: _createExpressiveTextTheme(Brightness.light),
    // Material 3 Expressive Shapes
    cardTheme: CardThemeData(
      elevation: 1,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 3,
      shape: CircleBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 3,
      height: 80,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 3,
      centerTitle: false,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 1,
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    // Enhanced visual density for touch targets
    visualDensity: VisualDensity.standard,
    // Material 3 motion specifications
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  static final _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6246EA), // Deep Purple
      brightness: Brightness.dark,
    ),
    // Material 3 Expressive Typography
    textTheme: _createExpressiveTextTheme(Brightness.dark),
    // Material 3 Expressive Shapes
    cardTheme: CardThemeData(
      elevation: 1,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 3,
      shape: CircleBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 3,
      height: 80,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 3,
      centerTitle: false,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 1,
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    // Enhanced visual density for touch targets
    visualDensity: VisualDensity.standard,
    // Material 3 motion specifications
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  // Material 3 Expressive Typography System
  static TextTheme _createExpressiveTextTheme(Brightness brightness) {
    // Base color for text based on brightness
    final Color onSurface = brightness == Brightness.light
        ? const Color(0xFF1D1B20)
        : const Color(0xFFE6E0E9);

    final Color onSurfaceVariant = brightness == Brightness.light
        ? const Color(0xFF49454F)
        : const Color(0xFFCAC4D0);

    return TextTheme(
      // Display styles - largest text on screen
      displayLarge: TextStyle(
        fontSize: 57,
        height: 1.12,
        letterSpacing: -0.25,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        height: 1.16,
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        height: 1.22,
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),

      // Headline styles - large text, shorter than display
      headlineLarge: TextStyle(
        fontSize: 32,
        height: 1.25,
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.29,
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.33,
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),

      // Title styles - medium emphasis text
      titleLarge: TextStyle(
        fontSize: 22,
        height: 1.27,
        letterSpacing: 0,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.50,
        letterSpacing: 0.15,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.43,
        letterSpacing: 0.1,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),

      // Body styles - used for longer form writing
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.50,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.43,
        letterSpacing: 0.25,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.33,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
      ),

      // Label styles - used for labels like button text
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.43,
        letterSpacing: 0.1,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.33,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.45,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w500,
        color: onSurfaceVariant,
      ),
    );
  }

  // Method to get dynamic color scheme from system (Android 12+)
  static Future<ColorScheme?> getDynamicColorScheme(
      Brightness brightness) async {
    try {
      return await DynamicColorPlugin.getCorePalette().then(
          (corePalette) => corePalette?.toColorScheme(brightness: brightness));
    } catch (e) {
      // Dynamic colors not supported, return null
      return null;
    }
  }

  // Enhanced method to create theme with dynamic colors if available
  static Future<ThemeData> createDynamicTheme(Brightness brightness) async {
    final dynamicColorScheme = await getDynamicColorScheme(brightness);

    if (dynamicColorScheme != null) {
      final baseTheme =
          brightness == Brightness.light ? _lightTheme : _darkTheme;
      return baseTheme.copyWith(
        colorScheme: dynamicColorScheme,
      );
    }

    // Fallback to seed-based color scheme
    return brightness == Brightness.light ? _lightTheme : _darkTheme;
  }

  // Method to harmonize colors with dynamic colors
  static Color harmonizeColor(Color color, ColorScheme dynamicColorScheme) {
    // Simple harmonization fallback without external blend library
    return Color.lerp(color, dynamicColorScheme.primary, 0.15) ?? color;
  }
}
