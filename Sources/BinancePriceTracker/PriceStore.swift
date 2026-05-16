import Foundation
import Combine

struct TickerData: Equatable {
    var symbol: String
    var lastPrice: Double = 0
    var bidPrice: Double = 0
    var askPrice: Double = 0
    var openPrice: Double = 0
    var highPrice: Double = 0
    var lowPrice: Double = 0
    var volume: Double = 0
    var lastUpdate: Date = .distantPast

    var changePercent: Double {
        guard openPrice > 0, lastPrice > 0 else { return 0 }
        return (lastPrice - openPrice) / openPrice * 100
    }

    var isUp: Bool { openPrice == 0 ? true : lastPrice >= openPrice }
}

struct DailySnapshot {
    var symbol: String
    var lastPrice: Double
    var openPrice: Double
    var highPrice: Double
    var lowPrice: Double
    var volume: Double
}

@MainActor
final class PriceStore: ObservableObject {
    @Published private(set) var tickers: [String: TickerData] = [:]

    /// bookTicker can fire 50+ Hz per symbol — coalesce per-symbol updates to 2 Hz
    /// so the UI doesn't visually jitter.
    private var lastEmit: [String: Date] = [:]
    private let minInterval: TimeInterval = 0.5

    func updateLive(symbol: String, bid: Double, ask: Double) {
        let now = Date()
        if let last = lastEmit[symbol], now.timeIntervalSince(last) < minInterval {
            return
        }
        lastEmit[symbol] = now

        let mid = (bid + ask) / 2
        var t = tickers[symbol] ?? TickerData(symbol: symbol)
        t.bidPrice = bid
        t.askPrice = ask
        t.lastPrice = mid
        t.lastUpdate = now
        tickers[symbol] = t
    }

    func updateDaily(_ snap: DailySnapshot) {
        var t = tickers[snap.symbol] ?? TickerData(symbol: snap.symbol)
        t.openPrice = snap.openPrice
        t.highPrice = snap.highPrice
        t.lowPrice = snap.lowPrice
        t.volume = snap.volume
        // Seed last price from REST until WS starts flowing.
        if t.lastPrice == 0 {
            t.lastPrice = snap.lastPrice
            t.lastUpdate = Date()
        }
        tickers[snap.symbol] = t
    }

    func retain(only keep: Set<String>) {
        for key in tickers.keys where !keep.contains(key) {
            tickers.removeValue(forKey: key)
            lastEmit.removeValue(forKey: key)
        }
    }
}
