# Flowrite TODO List

This document outlines the planned features, enhancements, and bug fixes for Flowrite. Contributions are welcome! If you'd like to work on any of these items, please see our [Contributing Guidelines](CONTRIBUTING.md).

## 🚀 High Priority Features

These are the next major features we want to add to Flowrite.

- [ ] **Markdown Support**: Implement a Markdown editor to allow for rich text formatting in notes. (Issue #)
  - [ ] Basic formatting (bold, italic, headers)
  - [ ] Checklists
  - [ ] Code blocks
- [ ] **In-line Formatting**: Add a toolbar for easy access to formatting options. (Issue #)
- [ ] **Comprehensive Testing**: Increase test coverage across the app. (Issue #)
  - [ ] Unit tests for services and providers
  - [ ] Widget tests for all screens and widgets
  - [ ] Integration tests for key user flows (e.g., login, note creation, sync)

## ✨ Enhancements & Optimizations

These items will improve the user experience and performance of the app.

- [ ] **Improve Error Handling**: Provide more specific and user-friendly error messages. (Issue #)
- [ ] **Implement Caching**: Cache frequently accessed data to improve performance and reduce Supabase reads. (Issue #)
- [ ] **Improve Error Reporting**: Integrate a crash reporting service to automatically report crashes and errors. (Issue #)
- [ ] **Add Analytics**: Integrate analytics to understand user behavior and guide future development. (Issue #)
- [ ] **UI/UX Polish**:
  - [ ] Refine animations and transitions. (Issue #)
  - [ ] Improve layout on different screen sizes (e.g., tablets, foldable devices). _(Good first issue)_ (Issue #)
  - [ ] Add more theme customization options. _(Good first issue)_ (Issue #)

## 🐛 Bug Fixes

Known bugs that need to be addressed.

- [ ] _No known bugs at the moment. If you find one, please [report it](https://github.com/pi22by7/flowrite/issues)!_

## 🛠️ Infrastructure & Housekeeping

Tasks related to the project's infrastructure and maintenance.

- [ ] **Documentation**:
  - [ ] Add API documentation using `dartdoc`. _(Good first issue)_ (Issue #)
  - [ ] Create a more detailed architecture overview. _(Good first issue)_ (Issue #)
- [ ] **Refactor Legacy Code**: Identify and refactor any parts of the codebase that could be improved. (Issue #)

## 💡 Ideas for the Future

Long-term ideas for the project.

- [ ] **Collaboration Features**: Allow multiple users to collaborate on the same note in real-time. (Issue #)
- [x] **Export Options**: Add the ability to export notes to different formats (e.g., PDF, TXT). (Issue #2)
- [ ] **iCloud Drive Sync Backend**: Add `ICloudSyncBackend` (iOS/macOS-only) implementing the `SyncBackend` interface alongside Supabase and WebDAV, gated by `Platform.isIOS || Platform.isMacOS`. Requires Xcode-side setup (iCloud container entitlement, Apple Developer Team/provisioning) that can't be scripted. (Issue #2, Phase 4 of the sync backend plan)
- [ ] **Plugin System**: Allow users to extend the app's functionality with plugins. (Issue #)
- [ ] **Mobile App Store**: Publish to Google Play Store and Apple App Store. (Issue #)
