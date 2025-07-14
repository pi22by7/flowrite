import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flowrite/providers/theme_provider.dart';

void main() {
  group('ThemeProvider Settings Persistence', () {
    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('should initialize with default values', () async {
      final themeProvider = ThemeProvider();
      
      // Wait a bit for async initialization
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(themeProvider.themeMode, AppThemeMode.system);
      expect(themeProvider.useDynamicColors, true);
    });

    test('should persist theme mode preference', () async {
      // Create first provider and change theme
      final themeProvider1 = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));
      
      themeProvider1.setThemeMode(AppThemeMode.dark);
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Create second provider to simulate app restart
      final themeProvider2 = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(themeProvider2.themeMode, AppThemeMode.dark);
    });

    test('should persist dynamic colors preference', () async {
      // Create first provider and toggle dynamic colors
      final themeProvider1 = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));
      
      themeProvider1.toggleDynamicColors();
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Create second provider to simulate app restart
      final themeProvider2 = ThemeProvider();
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(themeProvider2.useDynamicColors, false);
    });
  });
}
