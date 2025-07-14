# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.0.0] - 2025-07-14

### BREAKING CHANGES

- **Migration from Firebase to Supabase**: Complete backend replacement for universal platform support
- **Environment variable configuration**: Secrets now managed via .env files instead of hardcoded values
- **Platform support expansion**: Now supports Linux, macOS, Windows, Android, iOS, and Web platforms
- **Authentication overhaul**: Cross-platform Google OAuth (web-based for desktop, native for mobile)

### Added

- Cross-platform authentication system with automatic platform detection
- Environment variable configuration with .env file support
- Supabase integration with PostgreSQL database and Row Level Security
- Desktop platform support (Linux, macOS, Windows) with web-based OAuth
- GitHub Secrets integration for CI/CD workflows
- Database migration system with SQL schema files

### Removed

- Firebase integration (Cloud Firestore, Firebase Auth)
- Firebase configuration files (google-services.json, GoogleService-Info.plist)
- Platform-specific Firebase dependencies

### Changed

- Build scripts now check for .env file configuration
- CI/CD workflows updated to use GitHub Secrets for environment variables
- Documentation updated to reflect Supabase setup requirements

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
