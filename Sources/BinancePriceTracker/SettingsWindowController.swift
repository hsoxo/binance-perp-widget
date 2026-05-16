import AppKit
import SwiftUI

/// LSUIElement apps can't reliably use the SwiftUI `Settings` scene + the
/// `showSettingsWindow:` action — the popover dismiss closes the responder
/// chain before the action lands. We manage an NSWindow ourselves instead.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let prefs: Preferences
    private let catalog: SymbolCatalog
    private var window: NSWindow?

    init(prefs: Preferences, catalog: SymbolCatalog) {
        self.prefs = prefs
        self.catalog = catalog
    }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(prefs: prefs, catalog: catalog))
            host.sizingOptions = [.preferredContentSize]
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 460),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            w.contentViewController = host
            w.title = "Binance Price Tracker"
            w.isReleasedWhenClosed = false
            w.setFrameAutosaveName("BinancePriceTrackerSettings")
            if w.frame.origin == .zero { w.center() }
            w.delegate = self
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
