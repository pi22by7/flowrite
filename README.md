# Flowrite 📝

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg?style=for-the-badge)](https://www.gnu.org/licenses/agpl-3.0)

Flowrite is a modern, intuitive songwriting and poetry app designed to help creators capture their inspiration anywhere, anytime. With seamless cloud sync, a clean, minimalist interface, and robust offline support, your creative process has never been more fluid.

## ✨ Features

- **Clean, Distraction-free Writing**: Focus on your creativity with our minimalist interface.
- **Cloud Sync**: Access your work across all your devices with Firebase Cloud Firestore.
- **Reliable Offline Support**: Write and edit anywhere, even without an internet connection. Your changes will sync automatically when you're back online.
- **Auto-save**: Never lose your work with automatic saving.
- **Material 3 Design**: A beautiful, modern UI with dynamic colors that adapt to your wallpaper (on supported Android devices).
- **Modern Typography**: Choose from a selection of beautiful, readable fonts to personalize your writing experience.
- **File Sorting**: Easily organize and find your files.
- **Dark Mode**: Easy on the eyes during late-night writing sessions.
- **Google Sign-in**: Secure and easy authentication.

## 🚀 Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

- Flutter SDK (latest stable version)
- A Firebase project set up.
  - Android: `google-services.json`
  - iOS: `GoogleService-Info.plist`
- An editor like Android Studio or VS Code

### Installation

1.  Clone the repository
    ```sh
    git clone https://github.com/pi22by7/flowrite.git
    ```
2.  Navigate to the project directory
    ```sh
    cd flowrite
    ```
3.  Install dependencies
    ```sh
    flutter pub get
    ```
4.  Run the app
    ```sh
    flutter run
    ```

## 🏗️ Built With

- [Flutter](https://flutter.dev/) - UI Framework
- [Firebase](https://firebase.google.com/) - Backend, Authentication & Database (Cloud Firestore)
- [Provider](https://pub.dev/packages/provider) - State Management
- [Google Sign In](https://pub.dev/packages/google_sign_in) - Authentication
- [dynamic_color](https://pub.dev/packages/dynamic_color) - Material 3 dynamic theming
- [shared_preferences](https://pub.dev/packages/shared_preferences) - Local storage
- [path_provider](https://pub.dev/packages/path_provider) - For finding commonly used locations on the filesystem.

## 🔒 Privacy & Security

- All data is encrypted in transit.
- Google Sign-in for secure authentication.
- Local storage for offline access.
- Cloud sync is automatic and seamless.

## 🗺️ Roadmap

- [x] Basic app structure and UI
- [x] Dark/Light theme support
- [x] Local file storage
- [x] Google Sign-in integration
- [x] Firebase Cloud Firestore integration
- [x] Auto-save functionality
- [x] File management (create, rename, delete)
- [x] Cloud sync capabilities
- [x] Reliable offline support and sync
- [x] Settings panel
- [x] Manual sync option
- [x] File conflict resolution
- [x] Material 3 UI with dynamic color
- [x] File sorting
- [ ] Markdown support
- [ ] In-line formatting
- [ ] Comprehensive error handling and user feedback
- [ ] Implement caching system for performance
- [ ] Add comprehensive testing (Unit, Widget, Integration)
- [ ] Improve error reporting (e.g., Crashlytics)
- [ ] Add analytics to understand user behavior
- [ ] Implement CI/CD pipeline for automated builds and releases

## 🤝 Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

We have a [TODO list](TODO.md) of features we'd like to add. If you'd like to contribute, please check out our [contributing guidelines](CONTRIBUTING.md).

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## 📄 License

This project is licensed under the AGPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## 📧 Contact

π - talk@pi22by7.me

Project Link: [https://github.com/pi22by7/flowrite](https://github.com/pi22by7/flowrite)

---

Made with ❤️ by π
