#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

EXEC_NAME="BinancePriceTracker"
APP_BUNDLE="Binance Price Tracker.app"
DIST_DIR="dist"
ZIP_NAME="${ZIP_NAME:-BinancePriceTracker-macos-universal.zip}"
DMG_NAME="${DMG_NAME:-BinancePriceTracker-macos-universal.dmg}"
UNIVERSAL_DIR=".build/universal"
UNIVERSAL_BIN="$UNIVERSAL_DIR/$EXEC_NAME"
DMG_STAGE="$DIST_DIR/dmg-stage"

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
cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXEC_NAME"

# Ad-hoc sign so macOS doesn't kill it for code-signature mismatches
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

echo "==> Creating release dmg..."
mkdir -p "$DIST_DIR"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"
cp -R "$APP_BUNDLE" "$DMG_STAGE/$APP_BUNDLE"
ln -s /Applications "$DMG_STAGE/Applications"
rm -f "$DIST_DIR/$DMG_NAME"
hdiutil create \
    -volname "Binance Price Tracker" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DIST_DIR/$DMG_NAME" >/dev/null
rm -rf "$DMG_STAGE"

if [ "${CREATE_ZIP:-0}" = "1" ]; then
    echo "==> Creating release zip..."
    rm -f "$DIST_DIR/$ZIP_NAME"
    ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$DIST_DIR/$ZIP_NAME"
fi

echo "==> Built: $APP_BUNDLE"
echo "==> Release dmg: $DIST_DIR/$DMG_NAME"
if [ "${CREATE_ZIP:-0}" = "1" ]; then
    echo "==> Release zip: $DIST_DIR/$ZIP_NAME"
fi
echo "Run with:  open \"$APP_BUNDLE\""
echo "Or:        ./run.sh"
