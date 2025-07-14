# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.1.0] - 2025-07-14

### ✨ Added
- **💾 Settings Persistence**: Theme preferences now persist across app restarts
- **🔄 Automatic Theme Restoration**: App remembers your last theme choice (System/Light/Dark)
- **📱 Cross-Platform Storage**: Settings sync works on all platforms (mobile, desktop, web)

### 🚀 Improved
- **🎨 Better Theme Experience**: Seamless theme switching with persistent preferences
- **⚡ Faster App Startup**: Theme applied immediately on launch without flickering
- **🛡️ Reliable Storage**: Robust error handling for settings persistence

### 🔧 Technical
- **SharedPreferences Integration**: Platform-appropriate storage mechanisms
- **State Management**: Enhanced ThemeProvider with persistent state
- **Error Handling**: Graceful fallbacks if storage is unavailable

## [3.0.0] - 2025-07-14

### ✨ What's New

- **🎨 System Theme Default**: Flowrite now automatically follows your device's system theme (light/dark mode)
- **🔄 Smart Theme Cycling**: Enhanced theme toggle with System → Light → Dark sequence
- **🌍 Universal Platform Support**: Now available for Android, iOS, Linux, macOS, Windows, and Web
- **🔐 Cross-Platform Authentication**: Seamless Google login across all platforms with automatic platform detection
- **📦 Multi-Platform Releases**: Automated builds for all supported platforms with graceful error handling

### 🚀 Major Improvements

- **🏗️ Backend Migration**: Complete migration from Firebase to Supabase for better cross-platform support
- **⚙️ Environment Configuration**: Secure .env file system for managing secrets and configuration
- **🖥️ Desktop Experience**: Full desktop support with web-based OAuth for Linux, macOS, and Windows
- **📱 Mobile Enhancement**: Improved mobile experience with native authentication flows
- **🌐 Web Deployment**: Static web app deployment capability for any hosting service

### 🔧 Technical Overhaul

- **Database**: PostgreSQL with Row Level Security via Supabase
- **Authentication**: Universal OAuth system with platform-specific implementations
- **Build System**: GitHub Actions workflows with multi-platform artifact management
- **Configuration**: Environment variable management via .env files and GitHub Secrets
- **Migration Tools**: SQL schema migration system for database updates

### 🗑️ Removed (Breaking Changes)

- **Firebase Integration**: Complete removal of Firebase (Cloud Firestore, Firebase Auth)
- **Legacy Configuration**: Removed platform-specific Firebase config files
- **Hardcoded Secrets**: Replaced with secure environment variable system

> **Migration Note**: This is a major version with breaking changes. Users upgrading from v2.x will need to set up new authentication due to the backend migration from Firebase to Supabase.

## [2.0.0] - 2025-07-11

### Major

- Complete CI/CD pipeline for Android releases
- Automated build and release workflow with GitHub Actions
- Multi-platform build scripts (now focused on Android)
- Material 3 expressive upgrade with dynamic colors and modern typography
- File sorting and streamlined creation flow
- Automated screenshot generation system (integration tests)
- Comprehensive documentation and contributing guidelines
- Code of conduct and issue templates

### Changed

- Improved workflow triggers (only builds Android)
- Updated README with new badges and versioning
- Enhanced sync reliability and modernized UI
- Better theme integration and UI consistency

### Fixed

- Updated Firebase packages and resolved Java 8 warnings
- Fixed Google Sign-In SHA-1 configuration
- Improved syllable counting and offline/cloud sync reliability

### Planned

- Enhanced search functionality
- Theme customization options
- Export/import capabilities
- Markdown support
- In-line formatting

## [1.2.0] - 2025-07-11

### Added

- Automated build and release workflows for multi-platform deployment
- Comprehensive CI/CD pipeline with GitHub Actions
- Automated screenshot generation system with integration tests
- Multi-platform build scripts (Android, Linux, Windows, macOS, Web)
- File sorting functionality (by name, date modified, creation date)
- Build status badges and version indicators in README
- Comprehensive documentation for building and releasing
- Contributing guidelines and issue templates
- Code of conduct for the project
- Automated changelog management

### Changed

- Upgraded to Material 3 with dynamic colors and modern typography
- Enhanced sync reliability and modernized UI
- Improved workflow triggers (no longer on every push, only when necessary)
- Updated README with detailed build instructions and release information
- Streamlined file creation flow
- Better theme integration across all screens

### Fixed

- Updated Firebase packages to latest versions
- Resolved Java 8 warnings
- Fixed Google Sign-In SHA-1 configuration
- Improved syllable counting accuracy
- Enhanced offline editing and cloud sync reliability
- Workflow efficiency improvements

## [1.1.0] - 2025-07-11

### Added

- Enhanced sync reliability features
- Modern UI improvements
- Better error handling for sync operations

### Changed

- Minor UI/UX improvements
- Configuration updates

### Fixed

- Firebase configuration improvements
- Various minor bug fixes

## [1.0.0] - 2024-11-15

### Added

- Initial release of Flowrite
- Clean, minimalist writing interface
- Firebase authentication and cloud sync
- Google Sign-In integration
- Offline writing capabilities
- Material 3 dynamic theming support
- Cross-platform support (Android, iOS, Linux, macOS, Windows, Web)
- Real-time auto-save functionality
- Dark/light theme support
- Responsive design for different screen sizes
- Rhyme coloring functionality
- Syllable counting features
- Custom font support with configurable sizes and line heights
- Cloud storage with real-time sync and local version merging
- File management (create, rename, delete)
- Reliable offline support and sync capabilities
- Settings panel with customization options
- Manual sync option
- File conflict resolution
