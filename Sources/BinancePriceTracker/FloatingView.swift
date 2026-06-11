import SwiftUI
import AppKit

/// Real behind-window blur. `.ultraThinMaterial` in SwiftUI uses
/// within-window vibrancy and looks like a solid card; `.behindWindow`
/// blends with whatever is on the desktop, which is the "real" translucency.
private struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        v.isEmphasized = false
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

private enum FloatPalette {
    // Macaron pastels — soft pill backgrounds + deeper, same-hue text.
    static let upFill   = Color(red: 0.74, green: 0.92, blue: 0.80)
    static let upText   = Color(red: 0.10, green: 0.45, blue: 0.22)
    static let downFill = Color(red: 1.00, green: 0.80, blue: 0.82)
    static let downText = Color(red: 0.66, green: 0.16, blue: 0.22)
}

struct FloatingView: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var store: PriceStore
    @State private var hovering = false

    var body: some View {
        let symbols = prefs.symbols.filter { $0.showInFloating }
        ZStack(alignment: .topTrailing) {
            content(symbols: symbols)
            if hovering {
                Button {
                    prefs.floatingWindowVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .background(Circle().fill(.thinMaterial))
                }
                .buttonStyle(.plain)
                .padding(4)
                .help("Hide")
            }
        }
        .onHover { hovering = $0 }
        .background {
            Group {
#if compiler(>=6.2)
                if #available(macOS 26.0, *) {
                    Color.clear
                        .glassEffect(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                }
#else
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
#endif
            }
            .opacity(prefs.floatingOpacity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func content(symbols: [TrackedSymbol]) -> some View {
        if symbols.isEmpty {
            Text("No symbols selected")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 0) {
                ForEach(symbols) { sym in
                    row(symbol: sym.symbol, ticker: store.tickers[sym.symbol])
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func row(symbol: String, ticker: TickerData?) -> some View {
        HStack(spacing: 8) {
            Text(PriceFormat.baseAsset(symbol))
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 6)
            if let t = ticker, t.lastPrice > 0 {
                Text(PriceFormat.precise(t.lastPrice))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.primary)
                changePill(value: t.changePercent, isUp: t.isUp)
            } else {
                Text("—")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
    }

    private func changePill(value: Double, isUp: Bool) -> some View {
        let fill = isUp ? FloatPalette.upFill : FloatPalette.downFill
        let text = isUp ? FloatPalette.upText : FloatPalette.downText
        return Text(PriceFormat.percent(value))
            .font(.system(.caption2, design: .monospaced).weight(.bold))
            .foregroundStyle(text)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(fill))
            .frame(width: 64, alignment: .trailing)
    }
}
