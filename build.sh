#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

EXEC_NAME="BinancePriceTracker"
APP_BUNDLE="Binance Price Tracker.app"
DIST_DIR="dist"
ZIP_NAME="${ZIP_NAME:-BinancePriceTracker-macos-universal.zip}"
UNIVERSAL_DIR=".build/universal"
UNIVERSAL_BIN="$UNIVERSAL_DIR/$EXEC_NAME"

echo "==> Building $EXEC_NAME (release, arm64)..."
swift build -c release --arch arm64

echo "==> Building $EXEC_NAME (release, x86_64)..."
swift build -c release --arch x86_64

echo "==> Creating universal binary..."
mkdir -p "$UNIVERSAL_DIR"
rm -f "$UNIVERSAL_BIN"
lipo -create \
    ".build/arm64-apple-macosx/release/$EXEC_NAME" \
    ".build/x86_64-apple-macosx/release/$EXEC_NAME" \
    -output "$UNIVERSAL_BIN"

echo "==> Packaging $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$UNIVERSAL_BIN" "$APP_BUNDLE/Contents/MacOS/$EXEC_NAME"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXEC_NAME"

# Ad-hoc sign so macOS doesn't kill it for code-signature mismatches
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "==> Creating release zip..."
mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/$ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$DIST_DIR/$ZIP_NAME"

echo "==> Built: $APP_BUNDLE"
echo "==> Release zip: $DIST_DIR/$ZIP_NAME"
echo "Run with:  open \"$APP_BUNDLE\""
echo "Or:        ./run.sh"
