#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIGURATION="${1:-release}"
APP_NAME="Dial"
APP_BUNDLE="$ROOT_DIR/build/${APP_NAME}.app"

swift build -c "$CONFIGURATION" --product DialApp
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BIN_DIR/DialApp" "$APP_BUNDLE/Contents/MacOS/DialApp"

if [ -d "$BIN_DIR/Dial_DialCore.bundle" ]; then
    cp -R "$BIN_DIR/Dial_DialCore.bundle" "$APP_BUNDLE/Contents/Resources/"
    cp -R "$BIN_DIR/Dial_DialCore.bundle" "$APP_BUNDLE/Contents/MacOS/"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>DialApp</string>
    <key>CFBundleIdentifier</key>
    <string>dev.mercha.dial</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Dial</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>dev.mercha.dial.import</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>dial</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_BUNDLE"
echo "Built $APP_BUNDLE"
