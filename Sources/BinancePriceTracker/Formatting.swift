import Foundation

enum PriceFormat {
    static func compact(_ price: Double) -> String {
        guard price.isFinite else { return "—" }
        if price >= 10_000 { return String(format: "%.0f", price) }
        if price >= 1_000  { return String(format: "%.1f", price) }
        if price >= 1      { return String(format: "%.3f", price) }
        if price >= 0.01   { return String(format: "%.4f", price) }
        return String(format: "%.6f", price)
    }

    static func precise(_ price: Double) -> String {
        guard price.isFinite else { return "—" }
        if price >= 1_000 { return String(format: "%.2f", price) }
        if price >= 1     { return String(format: "%.4f", price) }
        if price >= 0.01  { return String(format: "%.5f", price) }
        return String(format: "%.7f", price)
    }

    static func percent(_ value: Double) -> String {
        String(format: "%+.2f%%", value)
    }

    /// "BTCUSDT" → "BTC". Falls back to the full symbol otherwise.
    static func baseAsset(_ symbol: String) -> String {
        for quote in ["USDT", "USDC", "BUSD", "FDUSD", "TUSD"] where symbol.hasSuffix(quote) {
            return String(symbol.dropLast(quote.count))
        }
        return symbol
    }
}
