// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  ThemeData get currentTheme => _isDarkMode ? _darkTheme : _lightTheme;

  static final _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF6246EA), // Deep Purple
      secondary: Color(0xFFE45858), // Pure White
      surface: Color(0xFFFFFFFE),
      onPrimary: Color(0xFFFFFFFE),
      onSecondary: Color(0xFFFFFFFE), // Dark Grey
      onSurface: Color(0xFF2B2C34),
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 8,
      shape: CircleBorder(),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        letterSpacing: 0.2,
      ),
    ),
  );

  static final _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF9D8DF1), // Light Purple
      secondary: Color(0xFFFF8E8E), // Deep Dark
      surface: Color(0xFF21212B), // Dark Grey
      onPrimary: Color(0xFF17171F),
      onSecondary: Color(0xFF17171F),
      onSurface: Color(0xFFFFFFFE),
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 8,
      shape: CircleBorder(),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        letterSpacing: 0.2,
      ),
    ),
  );
}
