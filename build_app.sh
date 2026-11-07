#!/bin/bash
set -e

APP_DIR="build/MouseControl.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

mkdir -p build

echo "Compiling MouseControl with target arm64-apple-macos14.0..."
DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer xcrun swiftc -target arm64-apple-macos14.0 Sources/*.swift Sources/Views/*.swift -o build/MouseControl

mkdir -p "$MACOS"
mkdir -p "$RESOURCES/Resources"

cp build/MouseControl "$MACOS/MouseControl"
chmod +x "$MACOS/MouseControl"

cp Resources/kreo_top_cutout.png "$RESOURCES/Resources/kreo_top_cutout.png"
cp Resources/kreo_side_cutout.png "$RESOURCES/Resources/kreo_side_cutout.png"
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$RESOURCES/AppIcon.icns"
fi

cat << 'PLIST' > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MouseControl</string>
    <key>CFBundleIdentifier</key>
    <string>com.codepuri.mousecontrol</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MouseControl</string>
    <key>CFBundleDisplayName</key>
    <string>Kreo Mouse Control</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSAccessibilityUsageDescription</key>
    <string>Kreo Mouse Control requires Accessibility to remap mouse side buttons and dispatch configured actions such as Wispr Flow dictation.</string>
    <key>NSInputMonitoringUsageDescription</key>
    <string>Kreo Mouse Control monitors mouse auxiliary buttons to suppress unwanted browser navigation and trigger assigned actions.</string>
</dict>
</plist>
PLIST

SIGN_IDENTITY="Developer ID Application: Totem Interactive (BKS6A8KSC2)"
if security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY"; then
    echo "Signing with Developer ID: $SIGN_IDENTITY..."
    codesign -s "$SIGN_IDENTITY" --force --deep "$APP_DIR"
else
    echo "Developer ID not found; signing with ad-hoc..."
    codesign -s - --force --deep "$APP_DIR"
fi

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR"

# Install into /Applications/Kreo Mouse Control.app for stable TCC tracking
INSTALLED_APP="/Applications/Kreo Mouse Control.app"
echo "Installing to $INSTALLED_APP..."
rm -rf "$INSTALLED_APP"
cp -R "$APP_DIR" "$INSTALLED_APP"

if security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY"; then
    codesign -s "$SIGN_IDENTITY" --force --deep "$INSTALLED_APP"
fi

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALLED_APP"

echo "Successfully built, signed with Developer ID, and installed to $INSTALLED_APP"
