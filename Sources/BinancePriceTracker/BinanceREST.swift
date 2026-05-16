import Foundation

/// Polls Binance USDT-M futures `/fapi/v1/ticker/24hr` to keep 24h open/high/
/// low/volume up to date alongside the realtime WebSocket price.
final class BinanceRestClient {
    private let endpoint = "https://fapi.binance.com/fapi/v1/ticker/24hr"
    private let pollInterval: TimeInterval
    private let onSnapshot: @Sendable (DailySnapshot) -> Void

    private let lock = NSLock()
    private var symbols: [String] = []
    private var pollTask: Task<Void, Never>?

    init(pollInterval: TimeInterval = 20,
         onSnapshot: @escaping @Sendable (DailySnapshot) -> Void) {
        self.pollInterval = pollInterval
        self.onSnapshot = onSnapshot
    }

    func setSymbols(_ syms: [String]) {
        lock.withLock { symbols = syms }
        refreshNow()
    }

    /// Trigger an immediate snapshot fetch outside the regular poll cadence.
    func refreshNow() {
        Task.detached(priority: .background) { [weak self] in
            await self?.fetchAll()
        }
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.fetchAll()
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
            }
        }
    }

    private func fetchAll() async {
        let syms = lock.withLock { symbols }
        for s in syms {
            await fetchOne(s)
        }
    }

    private func fetchOne(_ symbol: String) async {
        guard let url = URL(string: "\(endpoint)?symbol=\(symbol)") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                NSLog("[BPT] REST 24hr %@ HTTP %d", symbol, http.statusCode)
                return
            }
            let r = try JSONDecoder().decode(Ticker24hResponse.self, from: data)
            let snap = DailySnapshot(
                symbol: r.symbol,
                lastPrice: Double(r.lastPrice) ?? 0,
                openPrice: Double(r.openPrice) ?? 0,
                highPrice: Double(r.highPrice) ?? 0,
                lowPrice: Double(r.lowPrice) ?? 0,
                volume: Double(r.volume) ?? 0
            )
            onSnapshot(snap)
        } catch {
            NSLog("[BPT] REST 24hr error %@: %@", symbol, error.localizedDescription)
        }
    }
}

private struct Ticker24hResponse: Decodable {
    let symbol: String
    let lastPrice: String
    let openPrice: String
    let highPrice: String
    let lowPrice: String
    let volume: String
}
