# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.4.0] - 2025-08-31

### ✨ Added

- **Rhyme Dictionary**: Comprehensive rhyme suggestion system powered by RhymeBrain API for professional songwriting assistance
  - **Smart Word Selection**: Select any word or phrase to find rhymes - works seamlessly on desktop, tablet, and mobile
  - **Perfect & Near Rhymes**: Categorized rhyme suggestions with perfect rhymes (exact matches) and near/slant rhymes for creative flexibility
  - **Syllable Information**: Each rhyme suggestion displays syllable count for better songwriting structure
  - **One-Tap Replacement**: Click any rhyme to instantly replace selected text in your lyrics
  - **Material 3 Design**: Beautiful animated popup with responsive design that adapts to all screen sizes
  - **Real-Time Updates**: Popup dynamically updates when selecting different words without needing to reopen
  - **Visual Feedback**: Sparkle button in header highlights when text is selected, indicating rhyme feature availability
  - **Hybrid Text System**: Maintains full rhyme coloring functionality while enabling proper text selection on all platforms
  - **RhymeBrain Attribution**: Compliant with API terms for application usage
- **Autosave System**: Implemented comprehensive autosave with 3-second timer, onBlur saves, and exit saves for seamless writing experience
- **Streamlined Song Creation**: Direct-to-editor flow - click "New" and immediately start writing without file dialog interruptions
- **In-Editor Title Editing**: Title field now integrated directly into editor content area with visual separation from body text
- **Body Placeholder Text**: Added "Write your song lyrics here..." hint to guide users and prevent title/body confusion

### 🚀 Improved

- **Editor User Experience**: Completely redesigned editing workflow - title and body editing in unified interface with Spectral typography
- **Save System**: Robust conflict resolution preventing duplicate saves, with visual feedback through smart button states
- **Exit Flow**: Eliminated confirmation dialogs - changes auto-save seamlessly, users can delete unwanted files if needed
- **Home Screen Layout**: Fine-tuned logo alignment with text baseline for professional visual balance
- **Service Names**: Refactored cloud services to generic names (removed Supabase-specific references for provider flexibility)
- **Editor Divider**: Enhanced title/body separator visibility for clearer content area distinction

### 🔧 Fixed

- **Accessibility**: Fixed + New button text color to meet WCAG contrast standards with proper theme-consistent colors
- **iOS Build**: Fixed Xcode simulator runtime version compatibility issues
- **macOS Build**: Updated macOS deployment target to 10.15+ for Flutter Assemble target to resolve google_sign_in_ios plugin compatibility
- **Production Logging**: Suppressed debug logs in release builds to prevent sensitive information exposure

### 🎨 Design

- **Desktop Authentication**: Enhanced OAuth success pages with professional Flowrite branding, Spectral wordmark, theme responsiveness, and improved user experience

### 📦 Dependencies

- Updated dependencies

## [3.3.2] - 2025-08-22

### ✨ Added

- **Logo Integration**: Added professional Flowrite logo to README and documentation
- **Custom App Icon**: Implemented Flowrite logomark as app launcher icon across all platforms

### 🔧 Improved

- **Brand Identity**: Enhanced visual branding with light/dark mode logo variants
- **App Icon**: Replaced default Flutter icon with custom Flowrite logomark for consistent branding (all icons currently bundled, will be optimized soon. Illustrator file also included in /assets/logo)

## [3.3.1] - 2025-07-19

### ✨ Added

- **Linux Desktop Authentication**: Implemented complete Google Sign-In support for Linux desktop using temporary OAuth server with proper token handling

### 🔧 Fixed

- **macOS Build**: Fixed macOS deployment target from 11.0 to 10.15 to resolve Google Sign-In iOS plugin compatibility issues
- **Desktop OAuth Flow**: Fixed authentication token parsing for desktop platforms using Supabase OAuth implicit flow
- **Cross-Platform Authentication**: Resolved platform-specific authentication routing for consistent sign-in experience

## [3.3.0] - 2025-07-16

### ✨ Enhanced

- **Syllable Counting**: Replaced manual dictionary with `english_words` package for more accurate and comprehensive syllable counting
- **Rhyme Detection**: Implemented CMU Pronouncing Dictionary integration for professional-grade rhyme detection using actual pronunciation data
- **Phonetic Analysis**: Uses the same pronunciation database as commercial speech software (CMU Sphinx, Festival TTS)
- **Bundled Dictionary**: CMU dictionary (126K+ words) now bundled with app for instant offline rhyme detection
- **Performance**: Lightning-fast rhyme detection with no network dependencies or caching complexity
- **Fallback System**: Graceful degradation to rule-based rhyme detection for edge cases
- **Memory Management**: Added cache clearing methods to prevent memory leaks during extended usage

### 🔧 Fixed

- **macOS Build**: Updated deployment target to 11.0 for Google Sign-In iOS compatibility

## [3.2.1] - 2025-07-16

### 🐛 Fixed

- **Web Platform File Saving**: Fixed file saving functionality on web browsers
- **Cross-Platform Storage**: Added platform-specific storage abstraction (web uses browser storage, mobile uses file system)
- **File Persistence**: Files now properly persist across browser sessions on web platform

## [3.2.0] - 2025-07-14

### ✨ Added

- **Production Deployment**: Complete Vercel integration with custom domain support
- **Enhanced Web Experience**: Improved SEO metadata and web build optimization
- **GitHub Actions Workflow**: Automated Vercel deployment with proper Flutter build environment

### 🔧 Fixed

- **OAuth Authentication**: Fixed OAuth redirect URLs for production deployment with custom domain support
- **Multi-Platform Builds**: Improved macOS 10.15+ compatibility and Windows PowerShell syntax
- **Build Pipeline**: Enhanced Android artifact naming and deployment workflow authentication
- **macOS Build**: Updated deployment target to 10.15+ for Google Sign-In compatibility
- **Windows Build**: Fixed PowerShell syntax for environment file creation in CI/CD

### 🚀 Improved

- **Web Deployment**: Optimized Vercel routing patterns and build verification
- **Development Workflow**: Better error handling and build verification in CI/CD pipeline
- **Cross-Platform Support**: Standardized build processes across all platforms

### 🔧 Technical

- **Vercel Configuration**: Enhanced web metadata, SEO optimization, and routing
- **Flutter Version**: Updated to 3.32.6 in deployment workflow
- **Build Artifacts**: Improved naming conventions and multi-platform compatibility
- **Xcode Project**: Updated macOS deployment target in all build configurations
- **GitHub Actions**: Fixed Windows PowerShell script syntax for environment variables
- **Build Pipeline**: Enhanced error handling for platform-specific dependencies

## [3.1.0] - 2025-07-14

### ✨ Added

- **Settings Persistence**: Theme preferences now persist across app restarts
- **Automatic Theme Restoration**: App remembers your last theme choice (System/Light/Dark)
- **Cross-Platform Storage**: Settings sync works on all platforms (mobile, desktop, web)

### 🚀 Improved

- **Better Theme Experience**: Seamless theme switching with persistent preferences
- **Faster App Startup**: Theme applied immediately on launch without flickering
- **Reliable Storage**: Robust error handling for settings persistence

### 🔧 Technical

- **SharedPreferences Integration**: Platform-appropriate storage mechanisms
- **State Management**: Enhanced ThemeProvider with persistent state
- **Error Handling**: Graceful fallbacks if storage is unavailable
- **macOS Deployment Target**: Updated to 10.15+ for compatibility with latest Google Sign-In

## [3.0.0] - 2025-07-14

### ✨ What's New

- **System Theme Default**: Flowrite now automatically follows your device's system theme (light/dark mode)
- **Smart Theme Cycling**: Enhanced theme toggle with System → Light → Dark sequence
- **Universal Platform Support**: Now available for Android, iOS, Linux, macOS, Windows, and Web
- **Cross-Platform Authentication**: Seamless Google login across all platforms with automatic platform detection
- **Multi-Platform Releases**: Automated builds for all supported platforms with graceful error handling

### 🚀 Major Improvements

- **Backend Migration**: Complete migration from Firebase to Supabase for better cross-platform support
- **Environment Configuration**: Secure .env file system for managing secrets and configuration
- **Desktop Experience**: Full desktop support with web-based OAuth for Linux, macOS, and Windows
- **Mobile Enhancement**: Improved mobile experience with native authentication flows
- **Web Deployment**: Static web app deployment capability for any hosting service

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
