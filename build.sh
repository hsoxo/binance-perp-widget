#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

EXEC_NAME="BinancePriceTracker"
APP_BUNDLE="Binance Price Tracker.app"
BUILD_DIR=".build/release"

echo "==> Building $EXEC_NAME (release)..."
swift build -c release

echo "==> Packaging $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$EXEC_NAME" "$APP_BUNDLE/Contents/MacOS/$EXEC_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXEC_NAME"

# Ad-hoc sign so macOS doesn't kill it for code-signature mismatches
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "==> Built: $APP_BUNDLE"
echo "Run with:  open \"$APP_BUNDLE\""
echo "Or:        ./run.sh"
