import AppKit
import SwiftUI

@MainActor
final class FloatingWindowController: NSObject, NSWindowDelegate, ObservableObject {
    private static let defaultPanelSize = NSSize(width: 260, height: 84)
    private static let minimumPanelSize = NSSize(width: 220, height: 44)
    private static let screenPadding: CGFloat = 24

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
            host.view.frame = NSRect(origin: .zero, size: Self.defaultPanelSize)

            let p = NSPanel(
                contentRect: NSRect(origin: .zero, size: Self.defaultPanelSize),
                styleMask: [.borderless, .nonactivatingPanel, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            p.contentViewController = host
            p.minSize = Self.minimumPanelSize
            p.contentMinSize = Self.minimumPanelSize
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.isFloatingPanel = true
            p.level = .floating
            p.hidesOnDeactivate = false
            p.isMovableByWindowBackground = true
            p.becomesKeyOnlyIfNeeded = true
            p.worksWhenModal = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            p.setFrameAutosaveName("BinancePriceFloatingPanel")
            p.delegate = self
            if p.frame.origin == .zero {
                p.setFrame(defaultFrame(size: p.frame.size), display: false)
            }
            ensureVisibleFrame(for: p)
            panel = p
        }

        if let panel {
            ensureVisibleFrame(for: panel)
            panel.orderFrontRegardless()
        }
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.prefs?.floatingWindowVisible = false
        }
    }

    private func ensureVisibleFrame(for panel: NSPanel) {
        guard let visibleFrame = bestVisibleFrame(for: panel.frame) else { return }

        var frame = panel.frame
        frame.size.width = min(
            max(frame.size.width, Self.minimumPanelSize.width),
            max(Self.minimumPanelSize.width, visibleFrame.width - Self.screenPadding * 2)
        )
        frame.size.height = min(
            max(frame.size.height, Self.minimumPanelSize.height),
            max(Self.minimumPanelSize.height, visibleFrame.height - Self.screenPadding * 2)
        )

        if !isUsablyVisible(frame) {
            frame = defaultFrame(in: visibleFrame, size: frame.size)
            NSLog("[BPT] Floating panel frame was off-screen; moved to %@", NSStringFromRect(frame))
        }

        panel.setFrame(frame, display: true)
    }

    private func isUsablyVisible(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            let intersection = screen.visibleFrame.intersection(frame)
            guard !intersection.isNull else { return false }
            return intersection.width >= min(80, frame.width * 0.5)
                && intersection.height >= min(32, frame.height * 0.5)
        }
    }

    private func bestVisibleFrame(for frame: NSRect) -> NSRect? {
        let screen = NSScreen.screens.first { screen in
            let intersection = screen.visibleFrame.intersection(frame)
            return !intersection.isNull && intersection.width > 0 && intersection.height > 0
        } ?? NSScreen.main ?? NSScreen.screens.first
        return screen?.visibleFrame
    }

    private func defaultFrame(size: NSSize) -> NSRect {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame
        return defaultFrame(in: visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768),
                            size: size)
    }

    private func defaultFrame(in visibleFrame: NSRect, size: NSSize) -> NSRect {
        NSRect(
            x: max(visibleFrame.minX + Self.screenPadding,
                   visibleFrame.maxX - size.width - Self.screenPadding),
            y: max(visibleFrame.minY + Self.screenPadding,
                   visibleFrame.maxY - size.height - Self.screenPadding),
            width: size.width,
            height: size.height
        )
    }
}
