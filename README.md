# Binance Price Tracker

A minimalist macOS menu-bar app that streams **Binance USDT-M perpetual futures**
prices over WebSocket and shows them in:

- the **menu bar** (live price text), and
- an optional **floating panel** that stays on top of every Space.

Both surfaces are configurable per symbol from a **Settings** window.

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+ toolchain (ships with Xcode 15 / Command Line Tools)

## Build & Run

```bash
chmod +x build.sh run.sh
./run.sh
```

This builds a universal release binary (`arm64` + `x86_64`), wraps it in
`Binance Price Tracker.app`, creates `dist/BinancePriceTracker-macos-universal.zip`,
and launches the app. The app has no Dock icon — look for the price in your
menu bar.

To rebuild after editing code:

```bash
./build.sh && ./run.sh
```

## Using it

1. Click the menu-bar item to open the popover.
2. Hit **Settings…** to add or remove symbols (e.g. `BTCUSDT`, `SOLUSDT`).
3. Per symbol, tick the **Menu Bar** and/or **Floating** checkboxes to choose
   where it shows up.
4. **Show Floating Window** opens a draggable always-on-top panel.

## How it works

- **Real-time price**: one combined WebSocket to
  `wss://fstream.binance.com/stream?streams=<sym>@bookTicker/...`
  — `bookTicker` pushes on every best-bid/ask change. The displayed price is
  `(bid + ask) / 2`.
  - `bookTicker` was picked over `miniTicker`/`aggTrade` because the latter
    two silently stop delivering frames on some networks even after the WS
    handshake succeeds. `bookTicker` is reliable everywhere we've tested.
- **24h open / high / low / volume**: a REST poll of
  `https://fapi.binance.com/fapi/v1/ticker/24hr?symbol=…` every 20 seconds.
- **Auto-reconnect** with exponential backoff (1s → 30s) on WS errors / closes.
- WS updates are throttled per symbol to ~10 Hz so SwiftUI doesn't repaint
  on every tick (bookTicker can fire 50+ Hz on active markets).
- All state lives in `PriceStore` (SwiftUI `ObservableObject`).
- Preferences persist to `UserDefaults`.

## File layout

```
Sources/BinancePriceTracker/
  App.swift                  # @main, Scenes
  AppCore.swift              # Wires Preferences <-> WS/REST <-> Store
  Preferences.swift          # Tracked symbols + per-surface flags
  PriceStore.swift           # Live ticker state (throttled @Published)
  BinanceWebSocket.swift     # bookTicker stream client
  BinanceREST.swift          # /fapi/v1/ticker/24hr poller
  Formatting.swift           # Price/percent formatters
  MenuBarViews.swift         # MenuBarExtra label + popover content
  FloatingWindowController.swift  # NSPanel host
  FloatingView.swift         # Floating panel UI
  SettingsView.swift         # Settings window
Resources/Info.plist         # LSUIElement = true → menu-bar-only app
build.sh                     # universal build -> .app + release zip (+ ad-hoc sign)
run.sh                       # build if needed, then open
```
