#!/bin/zsh
# Builds First Light.app from the SwiftPM FirstLight executable.
# Output: dist/First Light.app
# Usage: Scripts/build-app.sh [--clean] [--install] [--release]
#   --clean    rm -rf .build first — forces a full rebuild. Use before a
#              release or if a run shows stale behavior: SwiftPM's incremental
#              build can occasionally serve a stale binary (seen after a branch
#              switch + large edit batch).
#   --install  also copy the finished bundle to /Applications
#   --release  sign for distribution (hardened runtime), notarize, staple,
#              and zip → dist/First-Light-<version>.zip. Requires:
#                CODESIGN_ID     "Developer ID Application: …" identity
#                NOTARY_PROFILE  a `xcrun notarytool store-credentials` profile
set -euo pipefail
cd "$(dirname "$0")/.."

CLEAN=0
INSTALL=0
RELEASE=0
for arg in "$@"; do
    case "$arg" in
        --clean)   CLEAN=1 ;;
        --install) INSTALL=1 ;;
        --release) RELEASE=1 ;;
        *) echo "unknown option: $arg (use --clean, --install and/or --release)" >&2; exit 2 ;;
    esac
done

if (( RELEASE )) && { [[ -z "${CODESIGN_ID:-}" ]] || [[ -z "${NOTARY_PROFILE:-}" ]] }; then
    echo "--release needs CODESIGN_ID (Developer ID Application identity) and" >&2
    echo "NOTARY_PROFILE (from: xcrun notarytool store-credentials)" >&2
    exit 2
fi

if (( CLEAN )); then
    echo "clean build: removing .build…"
    rm -rf .build
fi

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

# NB: `|| true` is load-bearing — with no git tags, `git describe` exits 128,
# and pipefail+set -e would otherwise abort the whole script here, leaving the
# bundle with no Info.plist (no icon, no bundle id, unsigned).
VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)
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

if (( RELEASE )); then
    # Distribution: hardened runtime + secure timestamp, then notarize.
    # No entitlements needed — no JIT, mic, or network.
    codesign --force --options runtime --timestamp --sign "$CODESIGN_ID" "$APP"
else
    codesign --force --deep --sign "${CODESIGN_ID:--}" "$APP"
fi
# Nudge Finder/Dock to drop any cached (pre-icon) artwork for the bundle
touch "$APP" "$APP/Contents/Info.plist"
# Stamp the Finder icon directly (bypasses LaunchServices caching)
swift Tools/seticon.swift dist/AppIcon.iconset/icon_512x512@2x.png "$APP" || true
echo "built $APP"
echo "(icon stale? run: killall Dock Finder)"

if (( RELEASE )); then
    ZIP="dist/First-Light-$VERSION.zip"
    # Submit a zip for notarization, staple the ticket to the app, then
    # re-zip — the stapled bundle is what users must receive.
    ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    spctl -a -vv "$APP" && echo "notarized + stapled: $ZIP"
fi

if (( INSTALL )); then
    rm -rf "/Applications/First Light.app"
    cp -R "$APP" /Applications/
    # Launchpad shows only the installed copy — the dist build artifact has the
    # same bundle id, so leaving it registered makes a duplicate app appear.
    LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
    "$LSREG" -f "/Applications/First Light.app" 2>/dev/null || true
    # Delete the dist copy outright. Leaving a launchable bundle under the home
    # dir lets Spotlight/LaunchServices auto-re-register it, so a plain `-u`
    # never holds and Launchpad shows a duplicate. /Applications is the one copy.
    "$LSREG" -u "$PWD/$APP" 2>/dev/null || true
    rm -rf "$APP"
    echo "installed to /Applications/First Light.app"
fi
