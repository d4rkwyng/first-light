#!/bin/zsh
# Builds First Light.app from the SwiftPM FirstLight executable.
# Output: dist/First Light.app
# Usage: Scripts/build-app.sh [--install]   (--install copies to /Applications)
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product FirstLight
BUILD_DIR=$(swift build -c release --show-bin-path)

APP="dist/First Light.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BUILD_DIR/FirstLight" "$APP/Contents/MacOS/First Light"
# The Apple1Core resource bundle (ROMs) must travel with the app;
# Bundle.module looks in Contents/Resources first.
cp -R "$BUILD_DIR/first-light_Apple1Core.bundle" "$APP/Contents/Resources/"
cp -R "$BUILD_DIR/first-light_FirstLight.bundle" "$APP/Contents/Resources/"
cp Sources/FirstLight/Resources/AppIcon.icns "$APP/Contents/Resources/"

VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
VERSION=${VERSION:-0.1.0}
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo 1)

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>First Light</string>
    <key>CFBundleIdentifier</key>
    <string>net.cyduck.FirstLight</string>
    <key>CFBundleName</key>
    <string>First Light</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>An Apple-1 tribute for Apple's 50th. Woz Monitor and Integer BASIC © Apple. Not affiliated with Apple Inc.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign "${CODESIGN_ID:--}" "$APP"
# Nudge Finder/Dock to drop any cached (pre-icon) artwork for the bundle
touch "$APP" "$APP/Contents/Info.plist"
# Stamp the Finder icon directly (bypasses LaunchServices caching)
swift Tools/seticon.swift dist/AppIcon.iconset/icon_512x512@2x.png "$APP" || true
echo "built $APP"
echo "(icon stale? run: killall Dock Finder)"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf "/Applications/First Light.app"
    cp -R "$APP" /Applications/
    echo "installed to /Applications/First Light.app"
fi
