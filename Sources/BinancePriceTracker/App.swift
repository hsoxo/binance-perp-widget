import SwiftUI

@main
struct BinancePriceTrackerApp: App {
    @StateObject private var core = AppCore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(core: core, prefs: core.prefs, store: core.store)
        } label: {
            MenuBarLabel(prefs: core.prefs, store: core.store)
        }
        .menuBarExtraStyle(.window)
    }
}
