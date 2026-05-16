import SwiftUI

private enum TechPalette {
    static let accentStart = Color(red: 0.31, green: 0.86, blue: 1.00)   // cyan
    static let accentEnd   = Color(red: 0.62, green: 0.42, blue: 1.00)   // violet
    // Macaron — soft pastel fills paired with deeper, same-hue text.
    static let upFill   = Color(red: 0.74, green: 0.92, blue: 0.80)
    static let upText   = Color(red: 0.10, green: 0.45, blue: 0.22)
    static let downFill = Color(red: 1.00, green: 0.80, blue: 0.82)
    static let downText = Color(red: 0.66, green: 0.16, blue: 0.22)
}

private let techGradient = LinearGradient(
    colors: [TechPalette.accentStart, TechPalette.accentEnd],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

struct MenuBarLabel: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var store: PriceStore

    var body: some View {
        Text(text)
    }

    private var text: String {
        let parts = prefs.symbols
            .filter { $0.showInMenuBar }
            .map { sym -> String in
                let base = PriceFormat.baseAsset(sym.symbol)
                if let t = store.tickers[sym.symbol] {
                    return "\(base) \(PriceFormat.compact(t.lastPrice))"
                }
                return "\(base) …"
            }
        if parts.isEmpty { return "Binance" }
        return parts.joined(separator: "  ")
    }
}

struct MenuBarContent: View {
    let core: AppCore
    @ObservedObject var prefs: Preferences
    @ObservedObject var store: PriceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            separator
            if prefs.symbols.isEmpty {
                emptyState
            } else {
                rows
            }
            separator
            footer
        }
        .frame(width: 320)
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        TechPalette.accentStart.opacity(0.10),
                        TechPalette.accentEnd.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [TechPalette.accentStart.opacity(0.18), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 220
                )
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(techGradient.opacity(0.55), lineWidth: 1)
        )
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 0.5)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("BINANCE · FUTURES")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .kerning(1.4)
                    .foregroundStyle(.primary)
                Text("USDT-M Perpetual")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(TechPalette.upText)
                        .frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .kerning(0.8)
                        .foregroundStyle(.secondary)
                }
                if let stamp = latestUpdateText {
                    Text(stamp)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var latestUpdateText: String? {
        let latest = store.tickers.values
            .map(\.lastUpdate)
            .filter { $0 > .distantPast }
            .max()
        guard let latest else { return nil }
        return Self.timeFormatter.string(from: latest)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No symbols configured")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
            Text("Open Settings to add e.g. BTCUSDT")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private var rows: some View {
        VStack(spacing: 6) {
            ForEach(prefs.symbols) { sym in
                TickerRow(symbol: sym.symbol, ticker: store.tickers[sym.symbol])
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        VStack(spacing: 2) {
            FooterButton(
                systemImage: prefs.floatingWindowVisible
                    ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle",
                title: prefs.floatingWindowVisible ? "Hide Floating Window" : "Show Floating Window"
            ) {
                core.toggleFloatingWindow()
            }
            FooterButton(systemImage: "gearshape", title: "Settings", shortcut: "⌘,") {
                core.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            FooterButton(systemImage: "power", title: "Quit", shortcut: "⌘Q") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

private struct FooterButton: View {
    let systemImage: String
    let title: String
    var shortcut: String? = nil
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.system(.callout, design: .rounded))
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(hover ? Color.primary.opacity(0.07) : .clear)
                    if hover {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(techGradient.opacity(0.4), lineWidth: 0.5)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct TickerRow: View {
    let symbol: String
    let ticker: TickerData?

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(PriceFormat.baseAsset(symbol))
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                Text(symbol)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            priceBlock
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var priceBlock: some View {
        if let t = ticker, t.lastPrice > 0 {
            VStack(alignment: .trailing, spacing: 3) {
                Text(PriceFormat.precise(t.lastPrice))
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                changePill(value: t.changePercent, isUp: t.isUp)
            }
        } else {
            Text("loading…")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func changePill(value: Double, isUp: Bool) -> some View {
        let fill = isUp ? TechPalette.upFill : TechPalette.downFill
        let text = isUp ? TechPalette.upText : TechPalette.downText
        return HStack(spacing: 3) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 8, weight: .bold))
            Text(PriceFormat.percent(value))
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
        }
        .foregroundStyle(text)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(fill))
    }
}
