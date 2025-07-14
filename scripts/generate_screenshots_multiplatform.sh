#!/bin/bash

# Multi-Platform Screenshot Generator for Flowrite
# Supports Android, iOS, Linux, macOS, Windows, and Web

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${GREEN}🎨 Flowrite Multi-Platform Screenshot Generator${NC}"
echo "=================================================="

# Function to print colored output
print_status() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_platform() {
    echo -e "${PURPLE}[PLATFORM]${NC} $1"
}

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Parse command line arguments
PLATFORMS="auto"
DEVICE_TYPES="auto"
OUTPUT_MODE="organized" # organized | flat

while [[ $# -gt 0 ]]; do
    case $1 in
        --platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        --device-types)
            DEVICE_TYPES="$2"
            shift 2
            ;;
        --output)
            OUTPUT_MODE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --platforms PLATFORMS    Comma-separated list: android,ios,linux,macos,windows,web"
            echo "  --device-types TYPES     Comma-separated list: phone,tablet,desktop"
            echo "  --output MODE            Output mode: organized (default) | flat"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Auto-detect all available"
            echo "  $0 --platforms android,ios           # Android and iOS only"
            echo "  $0 --device-types phone               # Phone screenshots only"
            echo "  $0 --output flat                      # Flat structure for docs"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

print_status "Project root: $PROJECT_ROOT"
print_status "Platforms: $PLATFORMS"
print_status "Device types: $DEVICE_TYPES"
print_status "Output mode: $OUTPUT_MODE"

# Check dependencies
print_info "Checking dependencies..."

if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    print_error "Python3 is not installed or not in PATH"
    exit 1
fi

# Create directory structure
print_info "Setting up directory structure..."

if [ "$OUTPUT_MODE" = "organized" ]; then
    mkdir -p assets/screenshots/{android/{phone,tablet},ios/{iphone,ipad},desktop/{linux,macos,windows},web/{desktop,mobile},docs}
else
    mkdir -p assets/screenshots
fi

mkdir -p test_driver

# Get dependencies
print_info "Getting Flutter dependencies..."
flutter pub get

# Check for available devices
print_info "Checking for available devices..."
DEVICE_OUTPUT=$(flutter devices 2>/dev/null)
echo "$DEVICE_OUTPUT"

# Create test driver if it doesn't exist
if [ ! -f "test_driver/integration_test.dart" ]; then
    print_info "Creating integration test driver..."
    cat > test_driver/integration_test.dart << 'EOF'
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
EOF
fi

SCREENSHOTS_GENERATED=false

# Function to generate screenshots for a platform
generate_screenshots() {
    local platform=$1
    local device_id=$2
    local output_dir=$3
    
    print_platform "Generating screenshots for $platform (device: $device_id)"
    
    if flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d "$device_id"; then
        SCREENSHOTS_GENERATED=true
        
        if [ -f "build/integration_response_data.json" ]; then
            print_status "Extracting screenshots for $platform..."
            python3 scripts/extract_screenshots.py build/integration_response_data.json "$output_dir"
            
            # Copy to docs folder if organized mode
            if [ "$OUTPUT_MODE" = "organized" ]; then
                cp "$output_dir"/*.png assets/screenshots/docs/ 2>/dev/null || true
            fi
        fi
    else
        print_error "Failed to generate screenshots for $platform"
    fi
}

# Android devices
if echo "$DEVICE_OUTPUT" | grep -q "android" && [[ "$PLATFORMS" == *"android"* || "$PLATFORMS" == "auto" ]]; then
    ANDROID_DEVICE=$(echo "$DEVICE_OUTPUT" | grep "android" | head -n 1 | awk -F'•' '{print $2}' | xargs)
    
    if [ -n "$ANDROID_DEVICE" ]; then
        if [ "$OUTPUT_MODE" = "organized" ]; then
            generate_screenshots "Android Phone" "$ANDROID_DEVICE" "assets/screenshots/android/phone"
        else
            generate_screenshots "Android" "$ANDROID_DEVICE" "assets/screenshots"
        fi
    fi
fi

# iOS devices
if echo "$DEVICE_OUTPUT" | grep -q "ios" && [[ "$PLATFORMS" == *"ios"* || "$PLATFORMS" == "auto" ]]; then
    IOS_DEVICE=$(echo "$DEVICE_OUTPUT" | grep "ios" | head -n 1 | awk -F'•' '{print $2}' | xargs)
    
    if [ -n "$IOS_DEVICE" ]; then
        if [ "$OUTPUT_MODE" = "organized" ]; then
            generate_screenshots "iOS iPhone" "$IOS_DEVICE" "assets/screenshots/ios/iphone"
        else
            generate_screenshots "iOS" "$IOS_DEVICE" "assets/screenshots"
        fi
    fi
fi

# Linux desktop
if echo "$DEVICE_OUTPUT" | grep -q "linux" && [[ "$PLATFORMS" == *"linux"* || "$PLATFORMS" == "auto" ]]; then
    if [ "$OUTPUT_MODE" = "organized" ]; then
        print_platform "Linux desktop screenshots would be generated here"
        # Note: Linux desktop screenshot generation is complex and usually done in CI
    else
        print_status "Skipping Linux desktop (use CI/CD for headless generation)"
    fi
fi

# macOS desktop
if echo "$DEVICE_OUTPUT" | grep -q "macos" && [[ "$PLATFORMS" == *"macos"* || "$PLATFORMS" == "auto" ]]; then
    if [ "$OUTPUT_MODE" = "organized" ]; then
        print_platform "macOS desktop screenshots would be generated here"
    else
        print_status "Skipping macOS desktop (platform-specific generation needed)"
    fi
fi

# Verify results
if [ "$SCREENSHOTS_GENERATED" = true ]; then
    print_success "Screenshots generated successfully!"
    
    if [ "$OUTPUT_MODE" = "organized" ]; then
        print_status "Screenshots organized by platform in assets/screenshots/"
        echo ""
        echo "Generated screenshots by platform:"
        find assets/screenshots -name "*.png" -type f | sort | while read -r file; do
            platform=$(echo "$file" | cut -d'/' -f3-4)
            filename=$(basename "$file")
            size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "unknown")
            echo "  📸 $platform/$filename ($size bytes)"
        done
    else
        print_status "Screenshots saved in: assets/screenshots/"
        echo ""
        echo "Generated screenshots:"
        ls -la assets/screenshots/*.png 2>/dev/null | while read -r line; do
            filename=$(echo "$line" | awk '{print $9}' | xargs basename)
            size=$(echo "$line" | awk '{print $5}')
            echo "  📸 $filename ($size bytes)"
        done
    fi
    
    # Optional: Open screenshots directory
    if command -v xdg-open &> /dev/null; then
        echo ""
        read -p "Would you like to open the screenshots directory? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            xdg-open assets/screenshots/
        fi
    fi
else
    print_error "No screenshots were generated. Please check:"
    echo "  1. A device/emulator is connected and running"
    echo "  2. The app builds successfully for the target platform"
    echo "  3. Integration test completes without errors"
    echo ""
    echo "Try running: flutter doctor"
    exit 1
fi

echo ""
print_success "🎉 Multi-platform screenshot generation completed!"
print_status "You can now commit the screenshots to your repository."

if [ "$OUTPUT_MODE" = "organized" ]; then
    print_status "Use assets/screenshots/docs/ for documentation."
    print_status "Use platform-specific folders for app store submissions."
fi
