import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

// Time-aware color temperature modes
enum TimeOfDay { morning, afternoon, evening, night }

class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _useDynamicColorsKey = 'use_dynamic_colors';
  static const String _useTimeAwareColorsKey = 'use_time_aware_colors';

  AppThemeMode _themeMode = AppThemeMode.system;
  bool _useDynamicColors = true;
  bool _useTimeAwareColors = false;
  ThemeData? _dynamicLightTheme;
  ThemeData? _dynamicDarkTheme;
  bool _isInitialized = false;

  ThemeProvider() {
    _initializeFromStorage();
  }

  AppThemeMode get themeMode => _themeMode;
  bool get useDynamicColors => _useDynamicColors;
  bool get useTimeAwareColors => _useTimeAwareColors;
  bool get isInitialized => _isInitialized;

  // Legacy getter for compatibility
  bool get isDarkMode => _themeMode == AppThemeMode.dark;

  // Get current time of day for color temperature
  TimeOfDay get currentTimeOfDay {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return TimeOfDay.morning;
    if (hour >= 12 && hour < 17) return TimeOfDay.afternoon;
    if (hour >= 17 && hour < 21) return TimeOfDay.evening;
    return TimeOfDay.night;
  }

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

      // Load time-aware colors preference
      _useTimeAwareColors = prefs.getBool(_useTimeAwareColorsKey) ?? false;

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

  /// Save time-aware colors preference to persistent storage
  Future<void> _saveTimeAwareColorsPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_useTimeAwareColorsKey, _useTimeAwareColors);
    } catch (e) {
      debugPrint('Failed to save time-aware colors preference: $e');
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

  void toggleTimeAwareColors() {
    _useTimeAwareColors = !_useTimeAwareColors;
    _saveTimeAwareColorsPreference(); // Persist the change
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
    ThemeData baseTheme;

    if (_useDynamicColors) {
      if (brightness == Brightness.dark && _dynamicDarkTheme != null) {
        baseTheme = _dynamicDarkTheme!;
      } else if (brightness == Brightness.light && _dynamicLightTheme != null) {
        baseTheme = _dynamicLightTheme!;
      } else {
        baseTheme = brightness == Brightness.dark ? _darkTheme : _lightTheme;
      }
    } else {
      baseTheme = brightness == Brightness.dark ? _darkTheme : _lightTheme;
    }

    // Apply time-aware color temperature if enabled
    if (_useTimeAwareColors) {
      return _applyTimeAwareColors(baseTheme, brightness);
    }

    return baseTheme;
  }

  /// Apply subtle color temperature shifts based on time of day
  ThemeData _applyTimeAwareColors(ThemeData theme, Brightness brightness) {
    final timeOfDay = currentTimeOfDay;
    final colorScheme = theme.colorScheme;

    // Subtle temperature shifts for different times of day
    Color shiftedSurface;
    Color shiftedOnSurface;

    if (brightness == Brightness.light) {
      switch (timeOfDay) {
        case TimeOfDay.morning:
          // Cooler, more blue-tinted (crisp morning light)
          shiftedSurface = _shiftColorTemperature(colorScheme.surface, -0.02);
          shiftedOnSurface = colorScheme.onSurface;
          break;
        case TimeOfDay.afternoon:
          // Neutral (default)
          shiftedSurface = colorScheme.surface;
          shiftedOnSurface = colorScheme.onSurface;
          break;
        case TimeOfDay.evening:
          // Warmer, golden hour glow
          shiftedSurface = _shiftColorTemperature(colorScheme.surface, 0.03);
          shiftedOnSurface = colorScheme.onSurface;
          break;
        case TimeOfDay.night:
          // Amber-tinted warmth (cozy evening)
          shiftedSurface = _shiftColorTemperature(colorScheme.surface, 0.04);
          shiftedOnSurface = colorScheme.onSurface;
          break;
      }
    } else {
      switch (timeOfDay) {
        case TimeOfDay.morning:
          // Slightly cooler for morning
          shiftedSurface = _shiftColorTemperature(colorScheme.surface, -0.01);
          shiftedOnSurface = colorScheme.onSurface;
          break;
        case TimeOfDay.afternoon:
          // Neutral
          shiftedSurface = colorScheme.surface;
          shiftedOnSurface = colorScheme.onSurface;
          break;
        case TimeOfDay.evening:
          // Warmer for evening
          shiftedSurface = _shiftColorTemperature(colorScheme.surface, 0.02);
          shiftedOnSurface = colorScheme.onSurface;
          break;
        case TimeOfDay.night:
          // Deep warm glow for night
          shiftedSurface = _shiftColorTemperature(colorScheme.surface, 0.03);
          shiftedOnSurface = colorScheme.onSurface;
          break;
      }
    }

    return theme.copyWith(
      colorScheme: colorScheme.copyWith(
        surface: shiftedSurface,
        onSurface: shiftedOnSurface,
      ),
    );
  }

  /// Shift color temperature (positive = warmer/more amber, negative = cooler/more blue)
  Color _shiftColorTemperature(Color color, double amount) {
    // Convert to HSL-like manipulation
    final hsl = HSLColor.fromColor(color);

    // Shift hue slightly towards warm (amber) or cool (blue)
    // Warm shift: move towards orange/amber (30-50 degrees)
    // Cool shift: move towards blue (200-240 degrees)
    double newHue = hsl.hue;

    if (amount > 0) {
      // Warm: shift towards amber (around 40 degrees)
      newHue = (hsl.hue + (amount * 5)) % 360;
    } else if (amount < 0) {
      // Cool: shift towards blue
      newHue = (hsl.hue - (amount.abs() * 5)) % 360;
    }

    // Also slightly adjust saturation for warmth
    final newSaturation = (hsl.saturation + (amount * 0.05)).clamp(0.0, 1.0);

    return hsl
        .withHue(newHue)
        .withSaturation(newSaturation)
        .toColor();
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
      primary: Color(0xFF1A7B72), // Flow Teal (Dark) - accent color
      onPrimary: Color(0xFFFFFDF7), // Warm white on primary
      secondary: Color(0xFF2B1E2F), // Deep Aubergine - accent
      onSecondary: Color(0xFFFFFDF7), // Warm white
      tertiary: Color(0xFF58465D), // Smoky Aubergine
      surface: Color(0xFFFFFDF7), // Warm Cream (like aged paper)
      surfaceContainerLowest: Color(0xFFFFFBF0), // Even warmer for depth
      surfaceContainerLow: Color(0xFFFFF9F0), // Bone white
      surfaceContainer: Color(0xFFFFF8ED), // Soft ivory
      onSurface: Color(0xFF1C1917), // Warm dark text (not pure black)
      onSurfaceVariant: Color(0xFF57534E), // Warm gray text
      outline: Color(0xFFE7E5E4), // Warm outline
      outlineVariant: Color(0xFFF5F5F4), // Subtle warm divider
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
      primary: Color(0xFF2AB3A6), // Flow Teal (Bright) - accent
      onPrimary: Color(0xFF1C1917), // Warm dark text on teal
      secondary: Color(0xFF2B1E2F), // Deep Aubergine - accent
      onSecondary: Color(0xFFFFFDF7), // Warm white
      tertiary: Color(0xFF58465D), // Smoky Aubergine
      surface: Color(0xFF1C1917), // Warm Charcoal (not pure black)
      surfaceContainerLowest: Color(0xFF0C0A09), // Deepest warm black
      surfaceContainerLow: Color(0xFF1C1917), // Warm charcoal
      surfaceContainer: Color(0xFF292524), // Lighter warm charcoal
      onSurface: Color(0xFFFAF8F5), // Warm white text (not pure white)
      onSurfaceVariant: Color(0xFFD6D3D1), // Warm gray text
      outline: Color(0xFF44403C), // Warm gray outline
      outlineVariant: Color(0xFF292524), // Subtle warm divider
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
  // Enhanced with larger sizes and more generous line heights for serene reading
  static TextTheme _createExpressiveTextTheme(Brightness brightness) {
    // Warm, literary colors for headings and body
    final Color headingColor = brightness == Brightness.light
        ? const Color(0xFF2B1E2F) // Deep Aubergine
        : const Color(0xFFFAF8F5); // Warm white

    final Color bodyColor = brightness == Brightness.light
        ? const Color(0xFF1C1917) // Warm dark text
        : const Color(0xFFFAF8F5); // Warm white text

    final Color secondaryColor = brightness == Brightness.light
        ? const Color(0xFF57534E) // Warm gray
        : const Color(0xFFD6D3D1); // Warm light gray

    return TextTheme(
      // Large display text uses Spectral for literary elegance
      displayLarge: TextStyle(
        fontFamily: 'Spectral',
        fontSize: 57,
        height: 1.15, // Slightly more generous
        letterSpacing: -0.25,
        fontWeight: FontWeight.w400,
        color: headingColor,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Spectral',
        fontSize: 34, // Increased from 32
        height: 1.3, // More generous
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: headingColor,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Spectral',
        fontSize: 30, // Increased from 28
        height: 1.35, // More generous
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: headingColor,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Spectral',
        fontSize: 26, // Increased from 24
        height: 1.4, // More generous
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: headingColor,
      ),
      // Body text with increased sizes and generous line heights for comfortable reading
      bodyLarge: TextStyle(
        fontSize: 18, // Increased from 16 for better readability
        height: 1.65, // Much more generous (from 1.5)
        letterSpacing: 0.3, // Slightly reduced for elegance
        fontWeight: FontWeight.w400,
        color: bodyColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 16, // Increased from 14
        height: 1.6, // More generous (from 1.43)
        letterSpacing: 0.15, // Slightly reduced
        fontWeight: FontWeight.w400,
        color: bodyColor,
      ),
      bodySmall: TextStyle(
        fontSize: 14, // Increased from 12
        height: 1.5, // More generous (from 1.33)
        letterSpacing: 0.2, // Slightly reduced
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
