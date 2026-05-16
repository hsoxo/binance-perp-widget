#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

APP_BUNDLE="Binance Price Tracker.app"

if [ ! -d "$APP_BUNDLE" ]; then
    ./build.sh
fi

# Kill any running instance first
pkill -f "Binance Price Tracker.app" 2>/dev/null || true
sleep 0.3

open "$APP_BUNDLE"
echo "Launched. Look in your menu bar."
