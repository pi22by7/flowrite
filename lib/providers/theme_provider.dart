import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _useDynamicColorsKey = 'use_dynamic_colors';
  
  AppThemeMode _themeMode = AppThemeMode.system;
  bool _useDynamicColors = true;
  ThemeData? _dynamicLightTheme;
  ThemeData? _dynamicDarkTheme;
  bool _isInitialized = false;

  ThemeProvider() {
    _initializeFromStorage();
  }

  AppThemeMode get themeMode => _themeMode;
  bool get useDynamicColors => _useDynamicColors;
  bool get isInitialized => _isInitialized;
  
  // Legacy getter for compatibility
  bool get isDarkMode => _themeMode == AppThemeMode.dark;

  /// Initialize theme settings from persistent storage
  Future<void> _initializeFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load theme mode preference
      final savedThemeModeIndex = prefs.getInt(_themeModeKey);
      if (savedThemeModeIndex != null && 
          savedThemeModeIndex >= 0 && 
          savedThemeModeIndex < AppThemeMode.values.length) {
        _themeMode = AppThemeMode.values[savedThemeModeIndex];
      }
      
      // Load dynamic colors preference
      _useDynamicColors = prefs.getBool(_useDynamicColorsKey) ?? true;
      
      // Load dynamic themes if enabled
      if (_useDynamicColors) {
        await _loadDynamicThemes();
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // Graceful fallback - use defaults if storage fails
      debugPrint('Failed to load theme preferences: $e');
      _isInitialized = true;
      if (_useDynamicColors) {
        await _loadDynamicThemes();
      }
      notifyListeners();
    }
  }

  /// Save theme mode preference to persistent storage
  Future<void> _saveThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeModeKey, _themeMode.index);
    } catch (e) {
      debugPrint('Failed to save theme mode preference: $e');
    }
  }

  /// Save dynamic colors preference to persistent storage
  Future<void> _saveDynamicColorsPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_useDynamicColorsKey, _useDynamicColors);
    } catch (e) {
      debugPrint('Failed to save dynamic colors preference: $e');
    }
  }

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
    _saveThemeMode(); // Persist the change
    notifyListeners();
  }

  void setThemeMode(AppThemeMode mode) {
    _themeMode = mode;
    _saveThemeMode(); // Persist the change
    notifyListeners();
  }

  void toggleDynamicColors() {
    _useDynamicColors = !_useDynamicColors;
    _saveDynamicColorsPreference(); // Persist the change
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
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF1A7B72), // Flow Teal (Dark) - for light theme
      onPrimary: Color(0xFF091313), // On Accent
      secondary: Color(0xFF2B1E2F), // Deep Aubergine
      onSecondary: Color(0xFFFAFBFC), // Porcelain
      tertiary: Color(0xFF58465D), // Smoky Aubergine
      surface: Color(0xFFFAFBFC), // Porcelain
      onSurface: Color(0xFF14161A), // Primary Text
      onSurfaceVariant: Color(0xFF3D4047), // Secondary Text
      outline: Color(0xFFE3E6EE), // Dividers/Borders
    ),
    fontFamily: 'Work Sans',
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
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF2AB3A6), // Flow Teal (Bright) - for dark theme
      onPrimary: Color(0xFF0A1917), // On Accent
      secondary: Color(0xFF2B1E2F), // Deep Aubergine
      onSecondary: Color(0xFFFAFBFC), // Porcelain
      tertiary: Color(0xFF58465D), // Smoky Aubergine
      surface: Color(0xFF0E0F12), // Graphite
      onSurface: Color(0xFFE8EAF0), // Primary Text (Dark)
      onSurfaceVariant: Color(0xFFB7BCC9), // Secondary Text (Dark)
      outline: Color(0xFF262A36), // Dividers/Borders (Dark)
    ),
    fontFamily: 'Work Sans',
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

  // Custom Typography System: Spectral (headings) + Work Sans (body)
  static TextTheme _createExpressiveTextTheme(Brightness brightness) {
    // Heading color: Deep Aubergine for light theme, Primary text for dark theme
    final Color headingColor = brightness == Brightness.light
        ? const Color(0xFF2B1E2F) // Deep Aubergine
        : const Color(0xFFE8EAF0); // Primary Text (Dark)

    final Color bodyColor = brightness == Brightness.light
        ? const Color(0xFF14161A) // Primary Text (Light)
        : const Color(0xFFE8EAF0); // Primary Text (Dark)

    final Color secondaryColor = brightness == Brightness.light
        ? const Color(0xFF3D4047) // Secondary Text (Light)
        : const Color(0xFFB7BCC9); // Secondary Text (Dark)

    return TextTheme(
      // Large display text uses Spectral with Deep Aubergine (light) / Primary (dark)
      displayLarge: TextStyle(
        fontFamily: 'Spectral',
        fontSize: 57,
        height: 1.12,
        letterSpacing: -0.25,
        fontWeight: FontWeight.w400,
        color: headingColor,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Spectral',
        fontSize: 32,
        height: 1.25,
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: headingColor,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Spectral',
        fontSize: 28,
        height: 1.29,
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: headingColor,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Spectral',
        fontSize: 24,
        height: 1.33,
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: headingColor,
      ),
      // Body text uses Work Sans with proper brand colors
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.50,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w400,
        color: bodyColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.43,
        letterSpacing: 0.25,
        fontWeight: FontWeight.w400,
        color: bodyColor,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.33,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
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
