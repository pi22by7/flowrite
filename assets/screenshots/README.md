# Multi-Platform Screenshot Management Strategy

## Directory Structure

```
assets/screenshots/
├── README.md                    # This file
├── *.png                        # Android screenshots (for README/docs)
├── android/
│   ├── phone/
│   │   ├── dark_theme.png      # 1080x2400 (typical Android phone)
│   │   ├── home_screen.png
│   │   └── ...
│   └── tablet/
│       ├── dark_theme.png      # 1600x2560 (Android tablet)
│       └── ...
├── ios/
│   ├── iphone/
│   │   ├── dark_theme.png      # 1179x2556 (iPhone 14 Pro)
│   │   └── ...
│   └── ipad/
│       ├── dark_theme.png      # 2048x2732 (iPad Pro)
│       └── ...
├── desktop/
│   ├── linux/
│   │   ├── dark_theme.png      # 1920x1080 (common desktop)
│   │   └── ...
│   ├── macos/
│   │   ├── dark_theme.png      # 2560x1600 (MacBook Pro)
│   │   └── ...
│   └── windows/
│       ├── dark_theme.png      # 1920x1080 (common Windows)
│       └── ...
└── web/
    ├── desktop/
    │   ├── dark_theme.png      # 1920x1080 (browser desktop)
    │   └── ...
    └── mobile/
        ├── dark_theme.png      # 375x812 (mobile browser)
        └── ...
```

## Platform Support Matrix

| Platform    | Integration Tests | Device Support   | Priority |
| ----------- | ----------------- | ---------------- | -------- |
| **Android** | ✅ Flutter Driver | Emulator/Device  | High     |
| **iOS**     | ✅ Flutter Driver | Simulator/Device | High     |
| **Linux**   | ✅ Flutter Test   | Desktop          | Medium   |
| **macOS**   | ✅ Flutter Test   | Desktop          | Medium   |
| **Windows** | ✅ Flutter Test   | Desktop          | Medium   |
| **Web**     | ✅ Deployed       | Browser          | High     |

## Screenshot Types by Use Case

### 1. **README & Documentation** (Always Android)

- README.md always shows Android phone screenshots
- Most accessible and commonly available platform
- Screenshots copied directly to `assets/screenshots/*.png` (flat structure for easy reference)
- Source screenshots remain in `assets/screenshots/android/phone/`

### 2. **App Store/Play Store** (Platform-specific sizing)

- Android: `assets/screenshots/android/` (1080x2400, 1600x2560)
- iOS: `assets/screenshots/ios/` (1179x2556, 2048x2732)

### 3. **Marketing** (Website, social media)

- High-quality desktop and mobile shots from `assets/screenshots/desktop/`
- Multiple platforms to show cross-platform support

### 4. **Development** (Visual regression testing)

- All platforms in organized structure for consistency checks
- Automated generation for CI/CD

## Implementation Strategy

### Phase 1: Enhanced Android & iOS ✅

- ✅ Android phone screenshots (current)
- ✅ iOS simulator support (implemented via GitHub Actions)
- 🔄 Add tablet/iPad support

### Phase 2: Desktop Platforms

- ✅ Linux desktop screenshots (implemented via GitHub Actions)
- ✅ macOS screenshots (implemented via GitHub Actions) 
- ✅ Windows screenshots (implemented via GitHub Actions)

### Phase 3: Web Platform

- ✅ Web deployment and screenshots (Vercel integration)
- 🔄 Responsive design testing (mobile/desktop)

### Phase 4: Automation & CI/CD

- ✅ Multi-platform GitHub Actions workflow
- 🔄 Automatic screenshot comparison
- 🔄 Platform-specific artifact upload
