#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/QuickDrop.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_PATH="$RESOURCES_DIR/QuickDrop.icns"

echo "Building QuickDrop (Release)..."
swift build -c release --package-path "$ROOT_DIR"

BIN_PATH="$(swift build -c release --show-bin-path --package-path "$ROOT_DIR")/QuickDrop"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/QuickDrop"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/QuickDrop"

if command -v iconutil >/dev/null 2>&1; then
    echo "Generating QuickDrop.icns..."
    swift "$ROOT_DIR/scripts/generate-icon.swift" "$ICON_PATH"
fi

# Ad-hoc sign so local launch works cleanly on Apple Silicon & Intel Macs
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built: $APP_BUNDLE"
echo "Run with: open \"$APP_BUNDLE\""
