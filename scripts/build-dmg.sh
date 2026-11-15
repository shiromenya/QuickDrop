#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/QuickDrop.app"
DMG_STAGE="$BUILD_DIR/dmg-stage"
DMG_PATH="$BUILD_DIR/QuickDrop.dmg"

if [[ ! -d "$APP_BUNDLE" ]]; then
    "$ROOT_DIR/scripts/build-app.sh"
fi

rm -rf "$DMG_STAGE" "$DMG_PATH"
mkdir -p "$DMG_STAGE"

cp -R "$APP_BUNDLE" "$DMG_STAGE/QuickDrop.app"
ln -s /Applications "$DMG_STAGE/Applications"

hdiutil create \
    -volname "QuickDrop" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGE"
echo "Built DMG: $DMG_PATH"
