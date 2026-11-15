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

BIN_DIR="$(swift build -c release --show-bin-path --package-path "$ROOT_DIR")"
BIN_PATH="$BIN_DIR/QuickDrop"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/QuickDrop"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/QuickDrop"

# Inject CFBundleShortVersionString from QUICKDROP_VERSION, $1, or an exact git tag (e.g. v0.1.2).
RAW_VERSION="${QUICKDROP_VERSION:-${1:-}}"
if [[ -z "$RAW_VERSION" ]] && command -v git >/dev/null 2>&1; then
    RAW_VERSION="$(git -C "$ROOT_DIR" describe --tags --exact-match 2>/dev/null || true)"
fi
CLEAN_VERSION="${RAW_VERSION#v}"
CLEAN_VERSION="${CLEAN_VERSION#V}"
if [[ "$CLEAN_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $CLEAN_VERSION" "$CONTENTS_DIR/Info.plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $CLEAN_VERSION" "$CONTENTS_DIR/Info.plist"
    echo "Set CFBundleShortVersionString to $CLEAN_VERSION"
fi

# Copy SwiftPM resource bundles (localized strings, etc.) into Contents/Resources.
find "$BIN_DIR" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$RESOURCES_DIR/" \;

if command -v iconutil >/dev/null 2>&1; then
    echo "Generating QuickDrop.icns..."
    swift "$ROOT_DIR/scripts/generate-icon.swift" "$ICON_PATH"
fi

# Ad-hoc sign so local launch works cleanly on Apple Silicon & Intel Macs
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built: $APP_BUNDLE"
echo "Run with: open \"$APP_BUNDLE\""
