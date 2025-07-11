#!/bin/bash

# Create placeholder screenshot files until real ones are generated
# This ensures the README displays properly even before running tests

SCREENSHOT_DIR="/home/pipi/Projects/Android/flowrite/assets/screenshots"
mkdir -p "$SCREENSHOT_DIR"

# Create a simple placeholder function
create_placeholder() {
    local filename="$1"
    local title="$2"
    
    # Create a simple SVG placeholder that can be converted to PNG
    cat > "${SCREENSHOT_DIR}/${filename}.svg" << EOF
<svg width="300" height="600" xmlns="http://www.w3.org/2000/svg">
  <rect width="300" height="600" fill="#f0f0f0" stroke="#ddd" stroke-width="2"/>
  <text x="150" y="300" text-anchor="middle" font-family="Arial, sans-serif" font-size="16" fill="#666">
    ${title}
  </text>
  <text x="150" y="330" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" fill="#999">
    Screenshot placeholder
  </text>
  <text x="150" y="350" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" fill="#999">
    Run ./scripts/generate_screenshots.sh
  </text>
  <text x="150" y="370" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" fill="#999">
    to generate real screenshots
  </text>
</svg>
EOF

    echo "Created placeholder: ${filename}.svg"
}

# Create placeholder screenshots
create_placeholder "home_screen" "Home Screen"
create_placeholder "editor_screen" "Editor Screen"
create_placeholder "settings_screen" "Settings Screen"
create_placeholder "new_file_dialog" "New File Dialog"
create_placeholder "dark_theme" "Dark Theme"
create_placeholder "navigation_drawer" "Navigation Drawer"

echo "✅ Placeholder screenshots created in assets/screenshots/"
echo "📝 To generate real screenshots, run: ./scripts/generate_screenshots.sh"
