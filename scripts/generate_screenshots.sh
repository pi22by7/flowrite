#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🎨 Flowrite Screenshot Generator${NC}"
echo "======================================"

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

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

print_status "Project root: $PROJECT_ROOT"

# Create screenshots directory if it doesn't exist
mkdir -p assets/screenshots

# Check if device/emulator is available
print_status "Checking for available devices..."
DEVICE_OUTPUT=$(flutter devices 2>/dev/null)

# Get dependencies
print_status "Getting Flutter dependencies..."
flutter pub get

# Run integration tests to generate screenshots
print_status "Running integration tests to capture screenshots..."

# Run integration tests to generate screenshots
print_status "Running integration tests to capture screenshots..."

# For Android
if echo "$DEVICE_OUTPUT" | grep -q "android"; then
    print_status "Running tests on Android device/emulator..."
    
    # Get the emulator ID
    ANDROID_DEVICE=$(echo "$DEVICE_OUTPUT" | grep "android" | head -n 1 | awk '{print $3}')
    
    if [ -n "$ANDROID_DEVICE" ]; then
        print_status "Using Android device: $ANDROID_DEVICE"
        flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d "$ANDROID_DEVICE"
        
        # Extract screenshots from JSON
        if [ -f "build/integration_response_data.json" ]; then
            print_status "Extracting screenshots from test data..."
            python3 scripts/extract_screenshots.py build/integration_response_data.json assets/screenshots/
        fi
    fi
fi

# For iOS (if available)
if echo "$DEVICE_OUTPUT" | grep -q "ios"; then
    print_status "Running tests on iOS device/simulator..."
    
    # Get the iOS device ID
    IOS_DEVICE=$(echo "$DEVICE_OUTPUT" | grep "ios" | head -n 1 | awk '{print $3}')
    
    if [ -n "$IOS_DEVICE" ]; then
        print_status "Using iOS device: $IOS_DEVICE"
        flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d "$IOS_DEVICE"
        
        # Extract screenshots from JSON
        if [ -f "build/integration_response_data.json" ]; then
            print_status "Extracting screenshots from test data..."
            python3 scripts/extract_screenshots.py build/integration_response_data.json assets/screenshots/
        fi
    fi
fi

# For Linux desktop (skip - not supported for screenshot generation)
if echo "$DEVICE_OUTPUT" | grep -q "linux"; then
    print_status "Skipping Linux desktop (not supported for screenshot generation)"
fi

# Check if screenshots were generated
if [ "$(ls -A assets/screenshots 2>/dev/null)" ]; then
    print_success "Screenshots have been generated successfully!"
    print_status "Screenshots saved in: assets/screenshots/"
    
    # List generated screenshots
    echo ""
    echo "Generated screenshots:"
    find assets/screenshots -name "*.png" -type f | sort
else
    print_error "No screenshots were generated. Please check:"
    echo "  1. A device/emulator is connected and running"
    echo "  2. The app builds successfully"
    echo "  3. Integration test completes without errors"
    echo ""
    echo "Try running: flutter doctor"
fi

echo ""
print_status "Screenshot generation completed!"
