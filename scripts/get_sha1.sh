#!/bin/bash
# Get SHA-1 fingerprint for debug keystore

echo "Debug keystore SHA-1 fingerprint:"
/home/pipi/.local/share/JetBrains/Toolbox/apps/android-studio/jbr/bin/keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | grep SHA1

echo -e "\nRelease keystore SHA-1 fingerprint (if exists):"
if [ -f "./android/app/release.keystore" ]; then
    /home/pipi/.local/share/JetBrains/Toolbox/apps/android-studio/jbr/bin/keytool -list -v -keystore ./android/app/release.keystore | grep SHA1
else
    echo "Release keystore not found"
fi
