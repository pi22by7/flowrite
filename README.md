<div align="center">
  <img src="assets/logo/Light Logo.svg" alt="Flowrite Logo" width="200">
</div>

# Flowrite 📝

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg?style=for-the-badge)](https://www.gnu.org/licenses/agpl-3.0)

[![Release](https://img.shields.io/github/v/release/pi22by7/flowrite?style=for-the-badge&logo=github)](https://github.com/pi22by7/flowrite/releases)
[![Build Status](https://img.shields.io/github/actions/workflow/status/pi22by7/flowrite/release.yml?style=for-the-badge&logo=github-actions)](https://github.com/pi22by7/flowrite/actions/workflows/release.yml)

**[🌐 Try Web Demo](https://flowrite.pi22by7.me)** | **[📥 Download](https://github.com/pi22by7/flowrite/releases/latest)** | **Current Version: v4.0.0** | **Flutter: 3.47.9**

A songwriter's sanctuary. Write lyrics anywhere, sync everywhere, lose nothing.

Run Flowrite on your own Linux server with Docker Compose, without Supabase or
Google sign-in. See the [self-hosting and offline setup guide](docs/SELF_HOSTING.md).

## 💖 Why This Exists

I started coding to build tools for my own creative work. My first vision was a simple space for songwriting, but I found almost nothing open source to learn from. That detour taught me what I needed to know, and now I'm back to that original dream.

**Flowrite is built on a simple belief: creating art should be free, uninterrupted, and yours.**

Picture this: you're mid-verse when the perfect line hits, then a full-screen ad breaks your flow. Or the app you trusted with your most personal work shuts down, taking everything with it.

Creative tools should be:

- **Accessible** to anyone, regardless of what they can pay
- **Transparent** about how they handle your work
- **Sustainable** through community, not extraction
- **Educational** for anyone who wants to learn

This is my contribution to that vision.

## 📱 Screenshots

<div align="center">
  <table>
    <tr>
      <td align="center">
        <img src="assets/screenshots/home_screen_empty.png" width="250" alt="Home Screen (Empty)">
        <br>
        <em>Home Screen (Empty)</em>
      </td>
      <td align="center">
        <img src="assets/screenshots/home_screen.png" width="250" alt="Home Screen">
        <br>
        <em>Home Screen</em>
      </td>
      <td align="center">
        <img src="assets/screenshots/editor_screen.png" width="250" alt="Editor Screen">
        <br>
        <em>Editor Screen</em>
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="assets/screenshots/settings_screen.png" width="250" alt="Settings Screen">
        <br>
        <em>Settings Screen</em>
      </td>
      <td align="center">
        <img src="assets/screenshots/dark_theme.png" width="250" alt="Dark Theme">
        <br>
        <em>Dark Theme</em>
      </td>
      <td align="center">
      </td>
    </tr>
  </table>
</div>

## ✨ What Makes It Different

**A Calm Space to Write**
Warm cream and charcoal palette. Time-aware greetings. Centered composition. Breathing button animation. Focus mode to hide everything but your words.

**Your Work, Always Safe**
Local-first architecture saves instantly. Sync happens quietly in background. Works offline, syncs when you're back. Smart retry with exponential backoff. Multi-device conflict resolution. Pending edits are retried after reconnecting.

**Songwriter's Tools**
Visual syllable patterns (dots, triangles, hexagons) that adapt to 1-12 syllables. Watercolor rhyme highlighting in 15 soft colors. CMU Pronouncing Dictionary with 126K+ words. Poetic rhyme categories: True Echoes, Gentle Echoes, Close Harmonies.

**Chords Attached to Lyrics**
Highlight a lyric and choose **Attach chord** from the selection menu, or use the music note button at the cursor. Chords appear above the lyrics and follow them as you edit. Drag a chord onto another word to move it; click to type a chord inline. Press Enter or click elsewhere to save, Escape to cancel, or clear the chord to remove it. Deleting the attached word removes its chord. Use the top-right **Chords** switch to hide or show chords; hidden chords remain attached as you edit, and their extra spacing collapses. The app remembers your choice. Songs with chords save and export as marked ChordPro text (`[Am]lyrics`), keeping chords together with the song during sync.

**Song Sections**
Type Markdown headings such as `## Verse 1`, `## Chorus`, or `## Bridge`. Headings display as bold section names, with the `#` markers hidden in the editor and preserved when saved or exported. Use the **Add section heading** button beside the song title to insert common sections, format the current line, or remove heading formatting. Section labels are excluded from rhyme colors and syllable counts.

**Just Works**
3-second autosave. Material 3 with dynamic color. Adaptive theming. Premium typography (34pt/18pt, 1.65 line height). File sorting and organization. Secure Google Sign-in. No ads, no paywalls.

## 📥 Download

Pre-built releases for Android, Linux, Windows, and macOS:

[📥 **Get Flowrite**](https://github.com/pi22by7/flowrite/releases/latest)

## 🚀 Quick Start

**Users**: Download, open, write. Optionally connect WebDAV or Supabase to sync across devices.

**Developers**: Clone, copy `.env.example` to `.env`, run `flutter pub get && flutter run`.

See [setup details](#for-developers) below.

## 🛠️ For Developers

### Prerequisites

- Flutter SDK (latest stable)
- Optional: a WebDAV server, or a Supabase project with Google OAuth, for sync
- Android Studio or VS Code

### Setup

```bash
git clone https://github.com/pi22by7/flowrite.git
cd flowrite
cp .env.example .env  # Cloud credentials are optional
flutter pub get
flutter run
```

### Testing

```sh
flutter test                      # Unit tests
flutter test integration_test/    # Integration tests
```

The **Validate all platforms** workflow runs analysis and the shared unit/widget
tests on pushes and pull requests, and compiles web, Android, iOS Simulator,
Linux, macOS, and Windows builds. It also supports manual runs in GitHub Actions.
It uses `.env.example` and does not publish builds or connect to production.
Android validation uses a debug APK; iOS validation uses an unsigned simulator
build. These checks do not verify store signing or installation on a device.

Run `flutter doctor -v` and `flutter devices` to check local platform support.
Android needs the Android SDK and an emulator or connected device. Linux needs
Clang, CMake, Ninja, and GTK development libraries. iOS/macOS builds require
macOS with Xcode; Windows builds require Windows with Visual Studio's C++ tools.

Shared widget tests exercise the editor without a native device. Before a
release, also run the app on each target device/simulator and check selecting
lyrics, attaching/editing/dragging chords, inserting text before an attached
word, headers and spaces, chord visibility, and saving/reopening the song and
dashboard preview. Check phone and desktop widths, light/dark themes, text size,
rhyme colors, and the full breathing-room range. Native keyboards, touch
selection, and OS input methods require this additional device testing.

### Screenshots

```sh
./scripts/generate_screenshots.sh  # Automated screenshot generation
```

Screenshots save to `assets/screenshots/`. See [docs/SCREENSHOTS.md](docs/SCREENSHOTS.md) for details.

### Building

```sh
./scripts/build.sh android        # Android APK/AAB
./scripts/build.sh linux          # Linux tar.gz
./scripts/build.sh all            # All platforms
```

### Releasing

```sh
./scripts/release.sh 4.0.1        # Bump version, create tag
git push origin main && git push origin v4.0.1
```

GitHub Actions handles automated builds for Android, Linux, Windows, macOS.

## 🗺️ What's Next

**Done**: Theme system, file management, cloud sync, offline support, Material 3 UI, rhyme detection, syllable counting, CI/CD pipeline

**Coming**: Markdown formatting, inline text styling, better error handling, performance optimization, comprehensive testing, crash reporting, analytics, import/export, collaboration, plugin system

Want to help? See [Contributing](#-contributing).

## 🏗️ Built With

- [Flutter](https://flutter.dev/) - Cross-platform UI
- [Supabase](https://supabase.com/) - Backend and auth
- [Provider](https://pub.dev/packages/provider) - State management
- [Google Sign In](https://pub.dev/packages/google_sign_in) - Authentication
- [dynamic_color](https://pub.dev/packages/dynamic_color) - Material 3 theming
- [shared_preferences](https://pub.dev/packages/shared_preferences) - Local storage
- [path_provider](https://pub.dev/packages/path_provider) - Filesystem access

## 🤝 Contributing

All contributions welcome. Beginner-friendly tasks in [TODO.md](TODO.md), from simple UI tweaks to complex backend work.

1. Fork the project
2. Create feature branch (`git checkout -b feature/YourFeature`)
3. Commit changes (`git commit -m 'Add YourFeature'`)
4. Push to branch (`git push origin feature/YourFeature`)
5. Open pull request

**Resources**: [TODO](TODO.md) | [Contributing Guide](CONTRIBUTING.md) | [Build Guide](docs/BUILD_RELEASE_GUIDE.md) | [Code of Conduct](CODE_OF_CONDUCT.md)

## 📚 Documentation

- [Build & Release Guide](docs/BUILD_RELEASE_GUIDE.md)
- [Contributing Guidelines](CONTRIBUTING.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [TODO](TODO.md)
- [Changelog](CHANGELOG.md)

## 🔒 Privacy

- Optional sync to your own WebDAV server; use HTTPS for transport encryption
- Synced document JSON is readable on the server; end-to-end encryption is not implemented
- Optional Google OAuth when using Supabase
- Local-first data storage
- No tracking, no ads

## 📄 License

AGPL-3.0 - see [LICENSE](LICENSE) file.

## 📧 Contact

π - talk@pi22by7.me
Project: [https://github.com/pi22by7/flowrite](https://github.com/pi22by7/flowrite)

---

Made with ❤️ by π
