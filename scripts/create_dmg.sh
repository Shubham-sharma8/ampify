#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

APP_NAME="Ampify"
VERSION="1.6.3"
ARCHIVE_PATH="$ROOT_DIR/build/Ampify.xcarchive"
EXPORT_DIR="$ROOT_DIR/build/ExportedDevID"
EXPORT_OPTIONS="$ROOT_DIR/build/ExportOptions-DevID.plist"
DMG_STAGING="$ROOT_DIR/build/dmg-staging"
RW_DMG="$ROOT_DIR/build/${APP_NAME}-rw.dmg"
FINAL_DMG="$ROOT_DIR/${APP_NAME}.dmg"
VERSIONED_DMG="$ROOT_DIR/${APP_NAME}-${VERSION}.dmg"
BG_PNG="$ROOT_DIR/00-dmg-background.png"

mkdir -p "$ROOT_DIR/build" "$ROOT_DIR/marketing/screenshots"

echo "1. Generating updated DMG background & installer preview..."
swift "$ROOT_DIR/scripts/generate_dmg_background.swift"

cat << 'EOF' > "$EXPORT_OPTIONS"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>9TKKPN6F59</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

echo "2. Archiving Ampify.xcodeproj..."
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
xcodebuild -project "$ROOT_DIR/Ampify.xcodeproj" \
    -scheme Ampify \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    -allowProvisioningUpdates \
    | tail -n 15

echo "3. Exporting signed Developer ID Application bundle (Team 9TKKPN6F59)..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates \
    | tail -n 15

rm -rf "$ROOT_DIR/Ampify.app"
cp -R "$EXPORT_DIR/Ampify.app" "$ROOT_DIR/Ampify.app"

echo "4. Verifying Developer ID Application signature..."
codesign -dvv "$ROOT_DIR/Ampify.app" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier|Timestamp"
codesign -dvv "$ROOT_DIR/Ampify.app/Contents/PlugIns/AmpifyWidgetExtension.appex" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier|Timestamp"

echo "5. Rendering real-app marketing screenshots (2560x1720 Retina)..."
"$ROOT_DIR/Ampify.app/Contents/MacOS/Ampify" --render-marketing "$ROOT_DIR/marketing/screenshots"

echo "6. Building local development copy for /Applications & WidgetKit gallery..."
xcodebuild -project "$ROOT_DIR/Ampify.xcodeproj" \
    -scheme Ampify \
    -configuration Release \
    -derivedDataPath "$ROOT_DIR/build/XcodeDerived" \
    build \
    | tail -n 10

pkill -f "Ampify.app/Contents/MacOS/Ampify" || true
rm -rf "/Applications/Ampify.app"
cp -R "$ROOT_DIR/build/XcodeDerived/Build/Products/Release/Ampify.app" "/Applications/Ampify.app"
pluginkit -a "/Applications/Ampify.app/Contents/PlugIns/AmpifyWidgetExtension.appex" || true
pluginkit -e use -i me.cogify.ampify.widget || true

echo "7. Staging DMG contents..."
rm -rf "$DMG_STAGING" "$RW_DMG" "$FINAL_DMG" "$VERSIONED_DMG"
mkdir -p "$DMG_STAGING/.background"
cp -R "$ROOT_DIR/Ampify.app" "$DMG_STAGING/Ampify.app"
ln -s /Applications "$DMG_STAGING/Applications"
cp "$BG_PNG" "$DMG_STAGING/.background/background.png"

echo "8. Creating read-write DMG and configuring Finder window layout..."
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDRW \
    "$RW_DMG" >/dev/null

DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" | awk '/\/Volumes\// {print $1; exit}')
sleep 2

osascript <<AppleScript || true
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {220, 160, 820, 588}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 108
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.png"
        set position of item "${APP_NAME}.app" of container window to {170, 195}
        set position of item "Applications" of container window to {430, 195}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
AppleScript

sync
hdiutil detach "$DEVICE" -quiet || hdiutil detach "$DEVICE" -force

echo "9. Compressing final DMG ($FINAL_DMG and $VERSIONED_DMG)..."
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" >/dev/null
cp "$FINAL_DMG" "$VERSIONED_DMG"
rm -rf "$RW_DMG" "$DMG_STAGING"

echo "Done! Signed Ampify.app packaged into:"
ls -lh "$FINAL_DMG" "$VERSIONED_DMG"
