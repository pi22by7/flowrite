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
  // Use pump() instead of pumpAndSettle() to avoid waiting for autosave timer
  await tester.pump(const Duration(milliseconds: 500));
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

    // New flow: FAB directly creates "Untitled Song" and opens editor (no dialog)
    // Use pump() with duration instead of pumpAndSettle() to avoid waiting for autosave timer
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // We should now be in the editor screen
    debugPrint('Should now be in editor screen...');

    // Find text fields and add some content
    final textFieldFinder = find.byType(TextField);
    if (textFieldFinder.evaluate().length >= 2) {
      debugPrint('Found text fields, adding sample content...');

      // First TextField is the title
      await tester.enterText(textFieldFinder.at(0), 'Morning Light');
      await tester.pump(const Duration(milliseconds: 500));

      // Second TextField is the content
      await tester.enterText(textFieldFinder.at(1),
        'Golden rays break through the night\n'
        'Dreams awaken in the light\n'
        'A new day starts to take its flight\n'
        'Everything feels just right'
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    } else {
      debugPrint('Could not find text fields for content');
    }

    // Take screenshot of editor screen with content
    debugPrint('Taking editor_screen screenshot...');
    await takeScreenshot(binding, tester, 'editor_screen');

    // Navigate back to home screen
    await navigateBack(tester);
  } else {
    debugPrint('FAB not found, continuing without file creation');
  }
}

Future<void> navigateBack(WidgetTester tester) async {
  final backButtonFinder = find.byIcon(Icons.arrow_back_rounded);
  if (backButtonFinder.evaluate().isNotEmpty) {
    debugPrint('Navigating back with back button...');
    await tester.tap(backButtonFinder.first);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  } else {
    debugPrint('Using Navigator.pop() to go back...');
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    if (navigator.canPop()) {
      navigator.pop();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }
}

Future<void> dismissDialog(WidgetTester tester) async {
  debugPrint('Dismissing dialog...');
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  if (navigator.canPop()) {
    navigator.pop();
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> captureSettingsScreen(
    WidgetTester tester, IntegrationTestWidgetsFlutterBinding binding) async {
  debugPrint('Opening settings...');
  final settingsButtonFinder = find.byIcon(Icons.settings_rounded);

  if (settingsButtonFinder.evaluate().isNotEmpty) {
    await tester.tap(settingsButtonFinder.first);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

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
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> toggleToDarkTheme(
    WidgetTester tester, IntegrationTestWidgetsFlutterBinding binding) async {
  debugPrint('Opening settings to toggle theme...');

  // Ensure any modal is dismissed first
  await dismissModal(tester);
  await tester.pump(const Duration(seconds: 1));

  // Open settings panel
  final settingsButtonFinder = find.byIcon(Icons.settings_rounded);
  if (settingsButtonFinder.evaluate().isEmpty) {
    debugPrint('Settings button not found, cannot toggle theme');
    await takeScreenshot(binding, tester, 'current_theme');
    return;
  }

  await tester.tap(settingsButtonFinder.first);
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));

  // Look for theme buttons in settings panel (new icons!)
  final systemModeButtonFinder = find.byIcon(Icons.brightness_auto_rounded);
  final darkModeButtonFinder = find.byIcon(Icons.nights_stay_rounded);
  final lightModeButtonFinder = find.byIcon(Icons.wb_sunny_rounded);

  debugPrint(
      'System mode button found: ${systemModeButtonFinder.evaluate().isNotEmpty}');
  debugPrint(
      'Dark mode button found: ${darkModeButtonFinder.evaluate().isNotEmpty}');
  debugPrint(
      'Light mode button found: ${lightModeButtonFinder.evaluate().isNotEmpty}');

  // Tap dark mode button
  if (darkModeButtonFinder.evaluate().isNotEmpty) {
    debugPrint('Found dark mode button, tapping...');
    await tester.tap(darkModeButtonFinder.first, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  } else if (lightModeButtonFinder.evaluate().isNotEmpty) {
    debugPrint('Currently in light mode, tapping to switch...');
    // In the new UI, we need to tap the container around the icon
    // Try finding the dark mode button differently
    await tester.tap(lightModeButtonFinder.first, warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  } else {
    debugPrint('No theme buttons found in settings');
  }

  // Close settings panel
  await dismissModal(tester);
  await tester.pump(const Duration(seconds: 1));

  debugPrint('Taking dark_theme screenshot...');
  await takeScreenshot(binding, tester, 'dark_theme');
}
