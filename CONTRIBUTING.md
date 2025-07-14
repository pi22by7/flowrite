# Contributing to Flowrite

First off, thank you for considering contributing to Flowrite! It's people like you that make the open-source community such a great place. We welcome any and all contributions.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Supabase Setup](#supabase-setup)
- [How to Contribute](#how-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Your First Code Contribution](#your-first-code-contribution)
  - [Pull Request Process](#pull-request-process)
- [Style Guides](#style-guides)
  - [Git Commit Messages](#git-commit-messages)
  - [Dart Style Guide](#dart-style-guide)
- [Architecture](#architecture)
- [Testing](#testing)
- [Questions?](#questions)

## Code of Conduct

This project and everyone participating in it is governed by the [Flowrite Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to [talk@pi22by7.me](mailto:talk@pi22by7.me).

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (latest stable version)
- An editor like [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/)
- A [Supabase project](https://supabase.com/docs/guides/getting-started)

### Installation

1.  **Fork** the repository on GitHub.
2.  **Clone** your forked repository to your local machine:
    ```sh
    git clone https://github.com/YOUR_USERNAME/flowrite.git
    cd flowrite
    ```
3.  **Install dependencies**:
    ```sh
    flutter pub get
    ```

### Supabase Setup

To run the app, you'll need to connect it to your own Supabase project.

1.  Create a new Supabase project in the [Supabase console](https://supabase.com/dashboard).
2.  Go to **Settings** → **API** and copy your project URL and anon key.
3.  Configure Google OAuth in your Supabase project:
    - Go to **Authentication** → **Settings** → **Auth Providers**
    - Enable **Google** provider
    - Add your Google OAuth client IDs for each platform you're building for
4.  Create environment variables file:
    ```bash
    cp .env.example .env
    ```
5.  Edit `.env` with your Supabase credentials:
    ```env
    SUPABASE_URL=your_supabase_project_url
    SUPABASE_ANON_KEY=your_supabase_anon_key
    GOOGLE_WEB_CLIENT_ID=your_google_web_client_id
    GOOGLE_ANDROID_CLIENT_ID=your_google_android_client_id
    GOOGLE_IOS_CLIENT_ID=your_google_ios_client_id
    PRODUCTION_URL=https://flowrite.pi22by7.me
    VERCEL_URL=https://flowrite-zeta.vercel.app
    ```

## How to Contribute

### Reporting Bugs

- Ensure the bug was not already reported by searching on GitHub under [Issues](https://github.com/pi22by7/flowrite/issues).
- If you're unable to find an open issue addressing the problem, [open a new one](https://github.com/pi22by7/flowrite/issues/new). Be sure to include a **title and clear description**, as much relevant information as possible, and a **code sample** or an **executable test case** demonstrating the expected behavior that is not occurring.

### Suggesting Enhancements

- Open a new issue to discuss your enhancement.
- Clearly describe the enhancement and the motivation for it.

### Your First Code Contribution

Unsure where to begin contributing to Flowrite? You can start by looking through these `good first issue` and `help wanted` issues:

- [Good first issues](https://github.com/pi22by7/flowrite/labels/good%20first%20issue) - issues which should only require a few lines of code, and a test or two.
- [Help wanted issues](https://github.com/pi22by7/flowrite/labels/help%20wanted) - issues which should be a bit more involved than `good first issue` issues.

### Pull Request Process

1.  Create a new branch for your feature or bug fix:
    ```sh
    git checkout -b feature/your-amazing-feature
    ```
2.  Make your changes.
3.  Commit your changes with a descriptive commit message (see [Git Commit Messages](#git-commit-messages)).
4.  Push your branch to your forked repository:
    ```sh
    git push origin feature/your-amazing-feature
    ```
5.  Open a pull request to the `main` branch of the original repository.
6.  Ensure the PR description clearly describes the problem and solution. Include the relevant issue number if applicable.

## Style Guides

### Git Commit Messages

- Use the present tense ("Add feature" not "Added feature").
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...").
- Limit the first line to 72 characters or less.
- Reference issues and pull requests liberally after the first line.

### Dart Style Guide

- Follow the official [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines.
- Run `dart format .` to format your code before committing.

## Architecture

Flowrite follows a standard Flutter project structure.

- `lib/main.dart`: App entry point.
- `lib/models`: Data models for the app (e.g., `Note`).
- `lib/providers`: State management using Provider.
- `lib/screens`: UI for different screens of the app.
- `lib/services`: Business logic and services (e.g., Supabase service).
- `lib/widgets`: Reusable widgets.
- `lib/utils`: Utility functions and constants.

## Testing

- Please add tests for any new features or bug fixes.
- Run existing tests to ensure you haven't introduced any regressions.
  ```sh
  flutter test
  ```

## Questions?

If you have any questions, feel free to open an issue or contact me at [talk@pi22by7.me](mailto:talk@pi22by7.me).
