import AppKit
import SwiftUI

@MainActor
final class FloatingWindowController: NSObject, NSWindowDelegate, ObservableObject {
    private weak var prefs: Preferences?
    private let store: PriceStore
    private var panel: NSPanel?

    init(prefs: Preferences, store: PriceStore) {
        self.prefs = prefs
        self.store = store
    }

    func setVisible(_ visible: Bool) {
        if visible { show() } else { hide() }
    }

    private func show() {
        if panel == nil {
            guard let prefs else { return }
            let host = NSHostingController(rootView: FloatingView(prefs: prefs, store: store))
            host.sizingOptions = [.preferredContentSize]

            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 210, height: 80),
                styleMask: [.borderless, .nonactivatingPanel, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            p.contentViewController = host
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.isFloatingPanel = true
            p.level = .floating
            p.hidesOnDeactivate = false
            p.isMovableByWindowBackground = true
            p.becomesKeyOnlyIfNeeded = true
            p.worksWhenModal = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            p.setFrameAutosaveName("BinancePriceFloatingPanel")
            p.delegate = self
            if p.frame.origin == .zero { p.center() }
            panel = p
        }
        panel?.orderFrontRegardless()
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.prefs?.floatingWindowVisible = false
        }
    }
}
