# Build and Release Guide

This document explains how to build and release Flowrite using the automated workflows and build scripts.

## 🚀 Release Workflows

### Workflow Triggers

We have optimized the GitHub Actions workflows to be more efficient:

#### Screenshots Workflow (`.github/workflows/screenshots.yml`)

- **Manual trigger**: Can be run manually from GitHub Actions
- **Selective push triggers**: Only runs when UI-related files change:
  - `lib/screens/**`
  - `lib/widgets/**`
  - `integration_test/**`
  - `assets/screenshots/**`
- **Pull requests**: Runs on PRs targeting main branch

#### Release Workflow (`.github/workflows/release.yml`)

- **Tag-based releases**: Automatically triggers on version tags (e.g., `v1.1.0`)
- **Manual releases**: Can be triggered manually with version input
- **Multi-platform builds**: Builds for Android, Linux, Windows, macOS
- **Automatic GitHub releases**: Creates release with all platform binaries

## 🛠️ Build Scripts

### Local Build Script (`scripts/build.sh`)

Build for specific platforms locally:

```bash
# Build Android APK and AAB
./scripts/build.sh android

# Build Linux executable
./scripts/build.sh linux

# Build for all supported platforms
./scripts/build.sh all

# Build debug version
./scripts/build.sh android debug
```

**Supported platforms:**

- `android` - APK and AAB files
- `linux` - Portable executable bundle
- `windows` - Portable executable (Windows only)
- `macos` - App bundle (macOS only)
- `ios` - iOS app (macOS only)
- `web` - Web application
- `all` - All platforms supported on current OS

### Release Script (`scripts/release.sh`)

Automate version bumping and release preparation:

```bash
# Create a new release
./scripts/release.sh 1.2.0

# Dry run to see what would happen
./scripts/release.sh 1.2.0 --dry-run
```

**What it does:**

1. Validates semantic versioning format
2. Updates `pubspec.yaml` with new version
3. Updates or creates `CHANGELOG.md`
4. Commits changes with proper message
5. Creates git tag for the release

## 📦 Release Process

### Automated Release (Recommended)

1. **Prepare release:**

   ```bash
   ./scripts/release.sh 1.2.0
   ```

2. **Push to trigger build:**

   ```bash
   git push origin main
   git push origin v1.2.0
   ```

3. **Monitor build:** Check GitHub Actions for build progress

4. **Release published:** Automatic release with all platform binaries

### Manual Release

1. **Update version** in `pubspec.yaml`
2. **Update** `CHANGELOG.md`
3. **Commit and tag:**
   ```bash
   git add .
   git commit -m "chore: bump version to 1.2.0"
   git tag v1.2.0
   git push origin main && git push origin v1.2.0
   ```

### Manual Workflow Trigger

You can also trigger releases manually from GitHub:

1. Go to **Actions** tab in GitHub
2. Select **Build and Release** workflow
3. Click **Run workflow**
4. Enter version tag (e.g., `v1.2.0`)
5. Click **Run workflow**

## 🏗️ Build Outputs

### Android

- **APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **AAB**: `build/app/outputs/bundle/release/app-release.aab`

### Linux

- **Executable**: `build/linux/x64/release/bundle/`
- **Package**: `flowrite-linux-x64-{version}.tar.gz`

### Windows

- **Executable**: `build/windows/x64/runner/Release/`
- **Package**: `flowrite-windows-x64-{version}.zip`

### macOS

- **App**: `build/macos/Build/Products/Release/flowrite.app`
- **Package**: `flowrite-macos-{version}.tar.gz`

### Web

- **Files**: `build/web/`

## 🔧 Configuration

### Environment Variables

The workflows use these environment variables:

- `FLUTTER_VERSION`: Currently set to `3.24.0`
- `GITHUB_TOKEN`: Automatically provided by GitHub Actions

### Workflow Customization

To modify build settings:

1. **Flutter version**: Update `FLUTTER_VERSION` in `.github/workflows/release.yml`
2. **Build options**: Modify build commands in workflow files
3. **Platforms**: Add/remove platform build jobs
4. **Triggers**: Adjust trigger conditions in workflow files

## 📋 Version Management

### Semantic Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Version Format

- **pubspec.yaml**: `version: MAJOR.MINOR.PATCH+BUILD`
- **Git tags**: `vMAJOR.MINOR.PATCH`
- **Releases**: `vMAJOR.MINOR.PATCH`

Example: `version: 1.2.3+45` → tag `v1.2.3`

## 🚨 Troubleshooting

### Common Issues

1. **Build fails on specific platform:**

   - Check platform-specific dependencies
   - Verify Flutter/SDK versions
   - Review error logs in GitHub Actions

2. **Version script fails:**

   - Ensure you're in git repository
   - Check version format (must be semantic)
   - Verify no uncommitted changes

3. **Release not created:**
   - Ensure tag was pushed: `git push origin v1.2.0`
   - Check GitHub Actions logs
   - Verify GITHUB_TOKEN permissions

### Getting Help

1. Check GitHub Actions logs for detailed error messages
2. Ensure all dependencies are properly installed
3. Verify Firebase configuration files are present
4. Test builds locally before creating releases

## 🔄 Workflow Efficiency

### Why We Changed the Triggers

**Before:** Workflows ran on every push to main branch
**Now:** Workflows run only when necessary

**Benefits:**

- Faster development cycle
- Reduced CI/CD resource usage
- Cleaner action history
- Focus on actual releases

**Screenshot workflow** only runs when:

- UI components change (`lib/screens/**`, `lib/widgets/**`)
- Integration tests change
- Manual trigger

**Release workflow** only runs when:

- Version tags are pushed
- Manual trigger for releases
