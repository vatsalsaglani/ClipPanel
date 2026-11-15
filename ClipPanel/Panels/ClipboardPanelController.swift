import AppKit
import SwiftUI

@MainActor
final class ClipboardPanelController: NSObject {
    private let state: ClipboardPanelState
    private let recordsProvider: () -> [ClipboardSearchItem]
    private let panelAnchorProvider: () -> PanelAnchor
    private let panelDensityProvider: () -> PanelDensity
    private let keepSearchQueryProvider: () -> Bool
    private let caretPointProvider: () -> CGPoint?
    private var panel: ClipboardPanel?
    private var keyMonitor: Any?
    private var previousApplication: NSRunningApplication?

    init(state: ClipboardPanelState, recordsProvider: @escaping () -> [ClipboardSearchItem], panelAnchorProvider: @escaping () -> PanelAnchor, panelDensityProvider: @escaping () -> PanelDensity, keepSearchQueryProvider: @escaping () -> Bool, caretPointProvider: @escaping () -> CGPoint?) {
        self.state = state
        self.recordsProvider = recordsProvider
        self.panelAnchorProvider = panelAnchorProvider
        self.panelDensityProvider = panelDensityProvider
        self.keepSearchQueryProvider = keepSearchQueryProvider
        self.caretPointProvider = caretPointProvider
    }

    func toggle() {
        guard panel?.isVisible != true else { dismiss(); return }
        present(query: keepSearchQueryProvider() ? state.query : "")
    }

    func show(query: String) {
        if panel?.isVisible == true { dismiss() }
        present(query: query)
    }

    private func present(query: String) {
        if let application = NSWorkspace.shared.frontmostApplication, application.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApplication = application
        }
        let records = recordsProvider()
        state.query = query
        state.begin(items: records, resetQuery: false)
        showPanel()
    }

    func dismiss() {
        panel?.orderOut(nil)
        removeKeyMonitor()
        state.statusMessage = nil
    }

    var priorApplication: NSRunningApplication? { previousApplication }

    private func showPanel() {
        let panel = makePanelIfNeeded()
        panel.contentView = NSHostingView(rootView: ClipboardPanelView(state: state, density: panelDensityProvider()))
        let desiredSize = CGSize(width: 560, height: state.results.isEmpty ? 190 : min(440, 132 + CGFloat(state.results.count) * 58))
        let geometries = NSScreen.screens.map { ScreenGeometry(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        let anchor = panelAnchorProvider()
        let point = anchor == .textCaret ? (caretPointProvider() ?? NSEvent.mouseLocation) : NSEvent.mouseLocation
        panel.setFrame(PanelPositioner.frame(panelSize: desiredSize, pointer: point, screens: geometries, anchor: anchor), display: true)
        panel.makeKeyAndOrderFront(nil)
        // A nonactivating panel borrows keyboard focus without deactivating the
        // destination app. Ordering it out returns focus to that app’s input.
        installKeyMonitor()
        state.focusGeneration += 1
    }

    private func makePanelIfNeeded() -> ClipboardPanel {
        if let panel { return panel }
        let panel = ClipboardPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.transient, .fullScreenAuxiliary, .moveToActiveSpace]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: ClipboardPanelView(state: state, density: panelDensityProvider()))
        self.panel = panel
        return panel
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isVisible == true else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            switch event.keyCode {
            case 126: self.state.moveSelection(by: -1); return nil
            case 125: self.state.moveSelection(by: 1); return nil
            case 53: self.state.send(.dismiss); return nil
            case 36, 76:
                AppLogger.panel.notice("Paste key received")
                if flags.contains(.option) { self.state.send(.copyOnly) }
                else if flags.contains(.shift) { self.state.send(.pastePlainText) }
                else { self.state.send(.pasteOriginal) }
                return nil
            case 35 where flags.contains(.command): self.state.send(.togglePin); return nil
            case 43 where flags.contains(.command): self.state.send(.openSettings); return nil
            default: return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
