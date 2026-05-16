import Foundation
import Combine
import AppKit

@MainActor
final class AppCore: ObservableObject {
    let prefs: Preferences
    let store: PriceStore
    let catalog: SymbolCatalog
    let floatingController: FloatingWindowController
    let settingsController: SettingsWindowController

    private let wsClient: BinanceWebSocketClient
    private let restClient: BinanceRestClient
    private var cancellables = Set<AnyCancellable>()

    init() {
        let p = Preferences()
        let s = PriceStore()
        let cat = SymbolCatalog()
        self.prefs = p
        self.store = s
        self.catalog = cat
        self.floatingController = FloatingWindowController(prefs: p, store: s)
        self.settingsController = SettingsWindowController(prefs: p, catalog: cat)

        self.wsClient = BinanceWebSocketClient { [weak s] symbol, bid, ask in
            Task { @MainActor in
                s?.updateLive(symbol: symbol, bid: bid, ask: ask)
            }
        }

        self.restClient = BinanceRestClient { [weak s] snapshot in
            Task { @MainActor in
                s?.updateDaily(snapshot)
            }
        }

        wireUp()
    }

    private func wireUp() {
        applySymbols()
        restClient.start()

        prefs.$symbols
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in self?.applySymbols() }
            }
            .store(in: &cancellables)

        if prefs.floatingWindowVisible {
            DispatchQueue.main.async { [weak self] in
                self?.floatingController.setVisible(true)
            }
        }

        prefs.$floatingWindowVisible
            .dropFirst()
            .sink { [weak self] visible in
                Task { @MainActor in self?.floatingController.setVisible(visible) }
            }
            .store(in: &cancellables)

        // The WebSocket task often stays half-open across a sleep/wake cycle —
        // no error, no didCloseWith — so no reconnect would ever fire. Listen
        // for the workspace wake notification and kick both transports.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.wsClient.forceReconnect()
                self?.restClient.refreshNow()
            }
        }
    }

    private func applySymbols() {
        let symbols = prefs.symbols.map { $0.symbol }
        wsClient.setSymbols(symbols)
        restClient.setSymbols(symbols)
        store.retain(only: Set(symbols))
    }

    func toggleFloatingWindow() {
        prefs.floatingWindowVisible.toggle()
    }

    func openSettings() {
        settingsController.show()
    }
}
