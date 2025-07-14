#!/bin/bash

# Complete screenshot generation and management script for Flowrite

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🎨 Flowrite Complete Screenshot System${NC}"
echo "============================================="

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

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

print_status "Project root: $PROJECT_ROOT"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

# Check if Python3 is installed
if ! command -v python3 &> /dev/null; then
    print_error "Python3 is not installed or not in PATH"
    exit 1
fi

# Create directories
print_info "Setting up directories..."
mkdir -p assets/screenshots
mkdir -p test_driver

# Step 1: Get dependencies
print_info "Getting Flutter dependencies..."
flutter pub get

# Step 2: Check for devices
print_info "Checking for available devices..."
DEVICE_OUTPUT=$(flutter devices 2>/dev/null)
echo "$DEVICE_OUTPUT"

# Step 3: Create test driver if it doesn't exist
if [ ! -f "test_driver/integration_test.dart" ]; then
    print_info "Creating integration test driver..."
    cat > test_driver/integration_test.dart << 'EOF'
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
EOF
fi

# Step 4: Run integration tests
print_info "Running integration tests to capture screenshots..."

SCREENSHOTS_GENERATED=false

# For Android
if echo "$DEVICE_OUTPUT" | grep -q "android"; then
    print_status "Found Android device/emulator"
    
    # Get the device ID (extract the device ID between the first set of bullet points)
    ANDROID_DEVICE=$(echo "$DEVICE_OUTPUT" | grep "android" | head -n 1 | awk -F'•' '{print $2}' | xargs)
    
    if [ -n "$ANDROID_DEVICE" ]; then
        print_status "Running tests on Android device: $ANDROID_DEVICE"
        
        if flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d "$ANDROID_DEVICE"; then
            SCREENSHOTS_GENERATED=true
            
            # Extract screenshots from JSON
            if [ -f "build/integration_response_data.json" ]; then
                print_status "Extracting screenshots from test data..."
                python3 scripts/extract_screenshots.py build/integration_response_data.json assets/screenshots
            fi
        fi
    fi
fi

# For iOS (if available)
if echo "$DEVICE_OUTPUT" | grep -q "ios"; then
    print_status "Found iOS device/simulator"
    
    IOS_DEVICE=$(echo "$DEVICE_OUTPUT" | grep "ios" | head -n 1 | awk -F'•' '{print $2}' | xargs)
    
    if [ -n "$IOS_DEVICE" ]; then
        print_status "Running tests on iOS device: $IOS_DEVICE"
        
        if flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d "$IOS_DEVICE"; then
            SCREENSHOTS_GENERATED=true
            
            if [ -f "build/integration_response_data.json" ]; then
                print_status "Extracting screenshots from test data..."
                python3 scripts/extract_screenshots.py build/integration_response_data.json assets/screenshots
            fi
        fi
    fi
fi

# For Linux desktop (skip - not supported for screenshot generation)
if echo "$DEVICE_OUTPUT" | grep -q "linux"; then
    print_status "Skipping Linux desktop (not supported for screenshot generation)"
fi

# Step 5: Verify screenshots were generated
if [ "$SCREENSHOTS_GENERATED" = true ] && [ "$(ls -A assets/screenshots/*.png 2>/dev/null)" ]; then
    print_success "Screenshots have been generated successfully!"
    print_status "Screenshots saved in: assets/screenshots/"
    
    # List generated screenshots
    echo ""
    echo "Generated screenshots:"
    ls -la assets/screenshots/*.png | while read -r line; do
        filename=$(echo "$line" | awk '{print $9}' | xargs basename)
        size=$(echo "$line" | awk '{print $5}')
        echo "  📸 $filename ($size bytes)"
    done
    
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
    echo "  2. The app builds successfully"
    echo "  3. Integration test completes without errors"
    echo ""
    echo "Try running: flutter doctor"
    exit 1
fi

echo ""
print_success "🎉 Complete screenshot generation finished!"
print_status "You can now commit the screenshots to your repository."
print_status "The README.md already includes the screenshot references."
