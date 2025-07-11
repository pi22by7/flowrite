#!/bin/bash

# Flowrite Build Script
# Usage: ./scripts/build.sh [platform] [mode]
# Platforms: android, ios, linux, windows, macos, web, all
# Modes: debug, release (default: release)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
PLATFORM=""
MODE="release"
VERSION=""
BUILD_NUMBER=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_usage() {
    echo "Usage: $0 [platform] [mode]"
    echo "Platforms: android, ios, linux, windows, macos, web, all"
    echo "Modes: debug, release (default: release)"
    echo ""
    echo "Examples:"
    echo "  $0 android"
    echo "  $0 linux debug"
    echo "  $0 all release"
}

log() {
    echo -e "${BLUE}[BUILD]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Extract version from pubspec.yaml
extract_version() {
    VERSION=$(grep '^version:' "$PROJECT_DIR/pubspec.yaml" | cut -d' ' -f2 | cut -d'+' -f1)
    BUILD_NUMBER=$(grep '^version:' "$PROJECT_DIR/pubspec.yaml" | cut -d'+' -f2)
    log "Version: $VERSION, Build: $BUILD_NUMBER"
}

# Setup Flutter
setup_flutter() {
    log "Setting up Flutter..."
    cd "$PROJECT_DIR"
    flutter pub get
    flutter doctor -v
}

# Build Android
build_android() {
    log "Building Android ($MODE)..."
    
    case $MODE in
        "debug")
            flutter build apk --debug --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            ;;
        "release")
            flutter build apk --release --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            flutter build appbundle --release --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            ;;
    esac
    
    success "Android build completed"
    log "APK location: build/app/outputs/flutter-apk/"
    if [ "$MODE" = "release" ]; then
        log "AAB location: build/app/outputs/bundle/release/"
    fi
}

# Build iOS
build_ios() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        error "iOS builds are only supported on macOS"
        return 1
    fi
    
    log "Building iOS ($MODE)..."
    
    case $MODE in
        "debug")
            flutter build ios --debug --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            ;;
        "release")
            flutter build ios --release --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            ;;
    esac
    
    success "iOS build completed"
    log "iOS app location: build/ios/iphoneos/"
}

# Build Linux
build_linux() {
    log "Building Linux ($MODE)..."
    
    flutter config --enable-linux-desktop
    
    case $MODE in
        "debug")
            flutter build linux --debug --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            ;;
        "release")
            flutter build linux --release --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            ;;
    esac
    
    success "Linux build completed"
    log "Linux app location: build/linux/x64/$MODE/bundle/"
    
    # Package for distribution
    if [ "$MODE" = "release" ]; then
        log "Packaging Linux release..."
        cd "build/linux/x64/release/bundle"
        tar -czf "../../../../../flowrite-linux-x64-$VERSION.tar.gz" .
        cd "$PROJECT_DIR"
        success "Linux package created: flowrite-linux-x64-$VERSION.tar.gz"
    fi
}

# Build Windows
build_windows() {
    log "Building Windows ($MODE)..."
    
    flutter config --enable-windows-desktop
    
    case $MODE in
        "debug")
            flutter build windows --debug --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            ;;
        "release")
            flutter build windows --release --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            ;;
    esac
    
    success "Windows build completed"
    log "Windows app location: build/windows/x64/runner/$MODE/"
    
    # Package for distribution (if zip is available)
    if [ "$MODE" = "release" ] && command -v zip &> /dev/null; then
        log "Packaging Windows release..."
        cd "build/windows/x64/runner/Release"
        zip -r "../../../../../flowrite-windows-x64-$VERSION.zip" .
        cd "$PROJECT_DIR"
        success "Windows package created: flowrite-windows-x64-$VERSION.zip"
    fi
}

# Build macOS
build_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        error "macOS builds are only supported on macOS"
        return 1
    fi
    
    log "Building macOS ($MODE)..."
    
    flutter config --enable-macos-desktop
    
    case $MODE in
        "debug")
            flutter build macos --debug --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            ;;
        "release")
            flutter build macos --release --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            ;;
    esac
    
    success "macOS build completed"
    log "macOS app location: build/macos/Build/Products/$MODE/"
    
    # Package for distribution
    if [ "$MODE" = "release" ]; then
        log "Packaging macOS release..."
        cd "build/macos/Build/Products/Release"
        tar -czf "../../../../../flowrite-macos-$VERSION.tar.gz" flowrite.app
        cd "$PROJECT_DIR"
        success "macOS package created: flowrite-macos-$VERSION.tar.gz"
    fi
}

# Build Web
build_web() {
    log "Building Web ($MODE)..."
    
    case $MODE in
        "debug")
            flutter build web --debug --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            ;;
        "release")
            flutter build web --release --build-name="$VERSION" --build-number="$BUILD_NUMBER"
            ;;
    esac
    
    success "Web build completed"
    log "Web app location: build/web/"
}

# Main script
main() {
    # Parse arguments
    if [ $# -eq 0 ]; then
        print_usage
        exit 1
    fi
    
    PLATFORM="$1"
    if [ $# -ge 2 ]; then
        MODE="$2"
    fi
    
    # Validate mode
    if [[ "$MODE" != "debug" && "$MODE" != "release" ]]; then
        error "Invalid mode: $MODE. Use 'debug' or 'release'"
        exit 1
    fi
    
    # Extract version
    extract_version
    
    # Setup Flutter
    setup_flutter
    
    # Build based on platform
    case $PLATFORM in
        "android")
            build_android
            ;;
        "ios")
            build_ios
            ;;
        "linux")
            build_linux
            ;;
        "windows")
            build_windows
            ;;
        "macos")
            build_macos
            ;;
        "web")
            build_web
            ;;
        "all")
            log "Building all supported platforms..."
            
            # Build all platforms that are supported on current OS
            build_android
            build_web
            build_linux
            
            if [[ "$OSTYPE" == "darwin"* ]]; then
                build_ios
                build_macos
            fi
            
            if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
                build_windows
            fi
            ;;
        *)
            error "Invalid platform: $PLATFORM"
            print_usage
            exit 1
            ;;
    esac
    
    success "Build process completed!"
}

# Run main function
main "$@"
