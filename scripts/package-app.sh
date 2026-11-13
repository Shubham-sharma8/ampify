#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

xcodebuild -project "$ROOT_DIR/Ampify.xcodeproj" \
    -target Ampify \
    -configuration Release \
    SYMROOT="$ROOT_DIR/build" \
    build

rm -rf "$ROOT_DIR/Ampify.app"
cp -Rf "$ROOT_DIR/build/Release/Ampify.app" "$ROOT_DIR/Ampify.app"

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "$ROOT_DIR/Ampify.app"
pluginkit -a "$ROOT_DIR/Ampify.app/Contents/PlugIns/AmpifyWidgetExtension.appex" || true
pluginkit -e use -i me.cogify.ampify.widget || true

echo "Packaged $ROOT_DIR/Ampify.app (from Ampify.xcodeproj with AmpifyWidgetExtension.appex)"
