# Screenshot Generation Guide

This document explains how to generate and manage screenshots for the Flowrite app.

## Overview

The Flowrite project includes automated screenshot generation using Flutter integration tests. Screenshots are used for:

- **Documentation**: README and project documentation
- **App Store Submissions**: Play Store and App Store listings
- **Marketing Materials**: Website and promotional content
- **Development Reference**: Visual regression testing

## Quick Start

### Automated Generation

```bash
# Run the automated screenshot script
./scripts/generate_screenshots.sh
```

This script will:

1. Check for connected devices/emulators
2. Install dependencies
3. Run integration tests
4. Capture screenshots
5. Organize them by platform

### Manual Generation

```bash
# Ensure device is connected
flutter devices

# Get dependencies
flutter pub get

# Run integration tests
flutter test integration_test/app_test.dart
```

## Screenshot Organization

Screenshots are organized in the following structure:

```
assets/screenshots/
├── android/
│   ├── home_screen.png
│   ├── editor_screen.png
│   ├── settings_screen.png
│   └── ...
├── ios/
│   ├── home_screen.png
│   ├── editor_screen.png
│   ├── settings_screen.png
│   └── ...
└── placeholders/
    ├── home_screen.svg
    └── ...
```

## Available Screenshots

The integration test captures the following screenshots:

1. **home_screen_empty.png** - Home screen with no files (first app launch)
2. **home_screen.png** - Home screen with files after creation
3. **new_file_dialog.png** - File creation dialog
4. **editor_screen.png** - Text editor interface with created file
5. **settings_screen.png** - Settings panel (light theme)
6. **settings_dark_mode.png** - Settings panel with dark mode toggle
7. **dark_theme.png** - App in dark theme
8. **sync_status.png** - Cloud sync status indicator

## Customizing Screenshots

### Adding New Screenshots

1. **Edit the integration test** (`integration_test/app_test.dart`):

   ```dart
   // Navigate to new screen
   await tester.tap(find.text('New Feature'));
   await tester.pumpAndSettle();

   // Capture screenshot
   await takeScreenshot(binding, tester, 'new_feature_screen');
   ```

2. **Update the README** to include the new screenshot:
   ```markdown
   <img src="assets/screenshots/new_feature_screen.png" width="250" alt="New Feature">
   ```

### Modifying Existing Screenshots

1. **Update the test logic** in `integration_test/app_test.dart`
2. **Regenerate screenshots** using the script
3. **Commit changes** to version control

## Platform-Specific Considerations

### Android

- Screenshots include system UI (status bar, navigation bar)
- Uses device-specific dimensions and DPI
- Material Design styling is captured accurately

### iOS

- Screenshots include iOS-specific UI elements
- Respects iOS safe areas and notches
- Cupertino styling variations are captured

### Desktop (Linux/Windows/macOS)

- Desktop-specific layouts and interactions
- Window chrome and titlebar included
- Higher resolution captures available

## Continuous Integration

Screenshots are automatically generated via GitHub Actions:

### Triggers

- Push to `main` branch with UI changes
- Pull requests affecting UI code
- Manual workflow dispatch

### Workflow File

`.github/workflows/screenshots.yml` contains the CI configuration.

### Artifacts

Generated screenshots are uploaded as build artifacts and can be downloaded from the Actions tab.

## Troubleshooting

### Common Issues

1. **No device connected**

   ```
   Error: No connected devices found
   ```

   **Solution**: Connect a device or start an emulator

2. **Test failures**

   ```
   Error: Widget not found
   ```

   **Solution**: Update test selectors in `app_test.dart`

3. **Build issues**
   ```
   Error: Build failed
   ```
   **Solution**: Run `flutter doctor` and fix issues

### Debug Mode

Run tests with verbose output:

```bash
flutter test integration_test/app_test.dart --verbose
```

### Manual Screenshot Capture

For one-off screenshots:

```bash
# Take a specific screenshot
flutter test integration_test/app_test.dart --driver-log-level=trace
```

## Best Practices

1. **Keep tests stable**: Use reliable selectors and proper waits
2. **Consistent data**: Use predictable test data for screenshots
3. **Multiple platforms**: Generate screenshots on different devices
4. **Regular updates**: Regenerate screenshots with UI changes
5. **Version control**: Commit screenshots to track visual changes

## Script Reference

### `scripts/generate_screenshots.sh`

Main screenshot generation script with error handling and platform detection.

### `scripts/create_placeholders.sh`

Creates SVG placeholder images for immediate use during development.

## Integration with README

Screenshots are automatically displayed in the README.md file. To update the layout:

1. **Edit the README** screenshot section
2. **Adjust image sizes** (recommended: 250px width)
3. **Update descriptions** to match new features
4. **Test markdown rendering** in your Git provider

## File Formats

- **PNG**: Primary format for actual screenshots
- **SVG**: Used for placeholders and vector graphics
- **JPEG**: Alternative format for larger images (if needed)

## Resolution Guidelines

- **Mobile**: 1080x1920 (or device-specific)
- **Tablet**: 1536x2048 (or device-specific)
- **Desktop**: 1920x1080 minimum

## Accessibility

Ensure screenshots represent:

- Both light and dark themes
- Various font sizes (if supported)
- Different screen densities
- Accessibility features enabled
