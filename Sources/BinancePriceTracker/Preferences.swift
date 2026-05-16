import Foundation
import Combine

struct TrackedSymbol: Codable, Identifiable, Equatable, Hashable {
    var symbol: String
    var showInMenuBar: Bool
    var showInFloating: Bool

    var id: String { symbol }
}

@MainActor
final class Preferences: ObservableObject {
    private static let symbolsKey = "trackedSymbols.v1"
    private static let floatingVisibleKey = "floatingWindowVisible.v1"
    private static let floatingOpacityKey = "floatingWindowOpacity.v1"

    @Published var symbols: [TrackedSymbol] {
        didSet { persistSymbols() }
    }

    @Published var floatingWindowVisible: Bool {
        didSet { UserDefaults.standard.set(floatingWindowVisible, forKey: Self.floatingVisibleKey) }
    }

    @Published var floatingOpacity: Double {
        didSet { UserDefaults.standard.set(floatingOpacity, forKey: Self.floatingOpacityKey) }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.symbolsKey),
           let decoded = try? JSONDecoder().decode([TrackedSymbol].self, from: data) {
            self.symbols = decoded
        } else {
            self.symbols = [
                TrackedSymbol(symbol: "BTCUSDT", showInMenuBar: true, showInFloating: true),
                TrackedSymbol(symbol: "ETHUSDT", showInMenuBar: true, showInFloating: true),
            ]
        }
        self.floatingWindowVisible = UserDefaults.standard.bool(forKey: Self.floatingVisibleKey)
        let stored = UserDefaults.standard.object(forKey: Self.floatingOpacityKey) as? Double
        self.floatingOpacity = stored ?? 1.0
    }

    private func persistSymbols() {
        guard let data = try? JSONEncoder().encode(symbols) else { return }
        UserDefaults.standard.set(data, forKey: Self.symbolsKey)
    }
}
