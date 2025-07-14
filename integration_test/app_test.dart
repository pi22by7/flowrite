import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flowrite/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Screenshots', () {
    testWidgets('Take screenshots of main app flows', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Wait for app to fully load and initialize
      await tester.pumpAndSettle(const Duration(seconds: 3));
      debugPrint('App fully loaded');

      // Convert surface once for all screenshots
      await binding.convertFlutterSurfaceToImage();
      debugPrint('Surface converted for screenshots');

      // 1. Take screenshot of home screen (empty state)
      debugPrint('Taking home_screen_empty screenshot...');
      await takeScreenshot(binding, tester, 'home_screen_empty');

      // 2. Create a new file using the custom FAB
      await createNewFile(tester, binding);

      // 3. Take screenshot of home screen with files (if file was created)
      debugPrint('Taking home_screen screenshot...');
      await takeScreenshot(binding, tester, 'home_screen');

      // 4. Open and screenshot settings panel
      await captureSettingsScreen(tester, binding);

      // 5. Toggle to dark theme and take screenshot
      await toggleToDarkTheme(tester, binding);

      // 6. Take final sync status screenshot
      debugPrint('Taking sync_status screenshot...');
      await takeScreenshot(binding, tester, 'sync_status');

      debugPrint('All screenshots completed successfully!');
    });
  });
}

Future<void> takeScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  await tester.pumpAndSettle();
  await binding.takeScreenshot(name);
  debugPrint('✓ Screenshot taken: $name');
}

Future<void> createNewFile(
    WidgetTester tester, IntegrationTestWidgetsFlutterBinding binding) async {
  debugPrint('Starting file creation flow...');

  // Look for the add icon (custom FAB uses Icons.add_rounded)
  final fabFinder = find.byIcon(Icons.add_rounded);

  if (fabFinder.evaluate().isNotEmpty) {
    debugPrint('Found custom FAB, tapping...');
    await tester.tap(fabFinder.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Take screenshot of new file dialog
    debugPrint('Taking new_file_dialog screenshot...');
    await takeScreenshot(binding, tester, 'new_file_dialog');

    // Enter file name
    final textFieldFinder = find.byType(TextField);
    if (textFieldFinder.evaluate().isNotEmpty) {
      debugPrint('Entering filename...');
      await tester.enterText(textFieldFinder.first, 'My Beautiful Song');
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Find and tap create button
      final createButtonFinder = find.text('Create');
      if (createButtonFinder.evaluate().isNotEmpty) {
        debugPrint('Tapping Create button...');
        await tester.tap(createButtonFinder.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Take screenshot of editor screen
        debugPrint('Taking editor_screen screenshot...');
        await takeScreenshot(binding, tester, 'editor_screen');

        // Navigate back to home screen
        await navigateBack(tester);
      } else {
        debugPrint('Create button not found, dismissing dialog');
        await dismissDialog(tester);
      }
    } else {
      debugPrint('TextField not found, dismissing dialog');
      await dismissDialog(tester);
    }
  } else {
    debugPrint('FAB not found, continuing without file creation');
  }
}

Future<void> navigateBack(WidgetTester tester) async {
  final backButtonFinder = find.byIcon(Icons.arrow_back);
  if (backButtonFinder.evaluate().isNotEmpty) {
    debugPrint('Navigating back with back button...');
    await tester.tap(backButtonFinder.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  } else {
    debugPrint('Using Navigator.pop() to go back...');
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    if (navigator.canPop()) {
      navigator.pop();
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
  }
}

Future<void> dismissDialog(WidgetTester tester) async {
  debugPrint('Dismissing dialog...');
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  if (navigator.canPop()) {
    navigator.pop();
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }
}

Future<void> captureSettingsScreen(
    WidgetTester tester, IntegrationTestWidgetsFlutterBinding binding) async {
  debugPrint('Opening settings...');
  final settingsButtonFinder = find.byIcon(Icons.settings_rounded);

  if (settingsButtonFinder.evaluate().isNotEmpty) {
    await tester.tap(settingsButtonFinder.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Take screenshot of settings screen
    debugPrint('Taking settings_screen screenshot...');
    await takeScreenshot(binding, tester, 'settings_screen');

    // Close settings modal
    await dismissModal(tester);
  } else {
    debugPrint('Settings button not found');
  }
}

Future<void> dismissModal(WidgetTester tester) async {
  debugPrint('Dismissing modal...');
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  if (navigator.canPop()) {
    navigator.pop();
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }
}

Future<void> toggleToDarkTheme(
    WidgetTester tester, IntegrationTestWidgetsFlutterBinding binding) async {
  debugPrint('Looking for theme toggle...');

  // Ensure any modal is dismissed first
  await dismissModal(tester);
  await tester.pumpAndSettle(const Duration(seconds: 1));

  // Look for theme buttons (system, dark mode, light mode)
  final systemModeButtonFinder = find.byIcon(Icons.brightness_auto_rounded);
  final darkModeButtonFinder = find.byIcon(Icons.dark_mode_rounded);
  final lightModeButtonFinder = find.byIcon(Icons.light_mode_rounded);

  debugPrint(
      'System mode button found: ${systemModeButtonFinder.evaluate().isNotEmpty}');
  debugPrint(
      'Dark mode button found: ${darkModeButtonFinder.evaluate().isNotEmpty}');
  debugPrint(
      'Light mode button found: ${lightModeButtonFinder.evaluate().isNotEmpty}');

  // Try to toggle to dark theme by tapping the theme button
  if (systemModeButtonFinder.evaluate().isNotEmpty) {
    debugPrint('App is in system mode, toggling to light mode...');
    await tester.tap(systemModeButtonFinder.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    
    // Look for dark mode button after first toggle
    final newDarkModeButtonFinder = find.byIcon(Icons.dark_mode_rounded);
    if (newDarkModeButtonFinder.evaluate().isNotEmpty) {
      debugPrint('Now toggling to dark mode...');
      await tester.tap(newDarkModeButtonFinder.first, warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }
    
    debugPrint('Taking dark_theme screenshot...');
    await takeScreenshot(binding, tester, 'dark_theme');
  } else if (darkModeButtonFinder.evaluate().isNotEmpty) {
    debugPrint('App is in light mode, toggling to dark mode...');
    await tester.tap(darkModeButtonFinder.first, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    debugPrint('Taking dark_theme screenshot...');
    await takeScreenshot(binding, tester, 'dark_theme');
  } else if (lightModeButtonFinder.evaluate().isNotEmpty) {
    debugPrint('App is already in dark mode');
    await takeScreenshot(binding, tester, 'dark_theme');
  } else {
    debugPrint('No theme toggle button found');
    await takeScreenshot(binding, tester, 'current_theme');
  }
}
