import Foundation
import Combine

/// Loads the set of tradable USDT-M perpetual symbols from
/// `/fapi/v1/exchangeInfo` so the Settings UI can reject typos before they
/// pollute the websocket subscription list.
@MainActor
final class SymbolCatalog: ObservableObject {
    @Published private(set) var symbols: Set<String> = []
    @Published private(set) var isLoaded: Bool = false

    private let exchangeInfoURL = URL(string: "https://fapi.binance.com/fapi/v1/exchangeInfo")!

    init() {
        Task { await self.refresh() }
    }

    func refresh() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: exchangeInfoURL)
            let info = try JSONDecoder().decode(ExchangeInfo.self, from: data)
            // Binance uses `PERPETUAL` for crypto perps and `TRADIFI_PERPETUAL`
            // for tradfi-linked perps (gold, silver, indices). Accept both.
            let allowedContractTypes: Set<String> = ["PERPETUAL", "TRADIFI_PERPETUAL"]
            let active = info.symbols
                .filter { $0.status == "TRADING" && allowedContractTypes.contains($0.contractType) }
                .map { $0.symbol }
            self.symbols = Set(active)
            self.isLoaded = true
        } catch {
            NSLog("[BPT] exchangeInfo error: %@", error.localizedDescription)
        }
    }

    /// Returns true if the symbol is a recognized USDT-M perpetual.
    /// Falls back to a one-shot HTTP probe when the catalog hasn't loaded yet.
    func validate(_ symbol: String) async -> Bool {
        if isLoaded { return symbols.contains(symbol) }
        await refresh()
        if isLoaded { return symbols.contains(symbol) }
        return await probe(symbol)
    }

    private func probe(_ symbol: String) async -> Bool {
        guard let url = URL(string: "https://fapi.binance.com/fapi/v1/ticker/24hr?symbol=\(symbol)") else {
            return false
        }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

private struct ExchangeInfo: Decodable {
    let symbols: [SymbolEntry]
}

private struct SymbolEntry: Decodable {
    let symbol: String
    let status: String
    let contractType: String
}
