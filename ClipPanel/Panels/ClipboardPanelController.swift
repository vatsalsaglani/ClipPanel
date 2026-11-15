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
    private let onWillPresent: () -> Void
    private var panel: ClipboardPanel?
    private var keyMonitor: Any?
    private var previousApplication: NSRunningApplication?
    private var feedbackPanel: NSPanel?
    private var feedbackTask: Task<Void, Never>?
    private var standardPanelHeight: CGFloat = 480

    init(state: ClipboardPanelState, recordsProvider: @escaping () -> [ClipboardSearchItem], panelAnchorProvider: @escaping () -> PanelAnchor, panelDensityProvider: @escaping () -> PanelDensity, keepSearchQueryProvider: @escaping () -> Bool, caretPointProvider: @escaping () -> CGPoint?, onWillPresent: @escaping () -> Void = {}) {
        self.state = state
        self.recordsProvider = recordsProvider
        self.panelAnchorProvider = panelAnchorProvider
        self.panelDensityProvider = panelDensityProvider
        self.keepSearchQueryProvider = keepSearchQueryProvider
        self.caretPointProvider = caretPointProvider
        self.onWillPresent = onWillPresent
        super.init()
        state.onPreviewVisibilityChanged = { [weak self] in self?.resizeForPreview() }
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
        onWillPresent()
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
        state.closePreview()
        removeKeyMonitor()
        state.statusMessage = nil
    }

    var priorApplication: NSRunningApplication? { previousApplication }

    private func showPanel() {
        let panel = makePanelIfNeeded()
        panel.contentView = NSHostingView(rootView: ClipboardPanelView(state: state, density: panelDensityProvider()))
        feedbackPanel?.orderOut(nil)
        let desiredSize = CGSize(width: 560, height: state.results.isEmpty ? 240 : min(480, 190 + CGFloat(state.results.count) * 58))
        standardPanelHeight = desiredSize.height
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

    /// A copy fallback must be visible without taking the destination app's keyboard focus.
    func showPasteFeedback(message: String) {
        feedbackTask?.cancel()
        let feedback = feedbackPanel ?? NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        feedback.level = .floating
        feedback.isOpaque = false
        feedback.backgroundColor = .clear
        feedback.hasShadow = true
        feedback.collectionBehavior = [.transient, .fullScreenAuxiliary, .moveToActiveSpace]
        feedback.contentView = NSHostingView(rootView:
            Label(message, systemImage: "doc.on.clipboard")
                .font(.callout)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel(message)
        )
        let screens = NSScreen.screens.map { ScreenGeometry(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        feedback.setFrame(PanelPositioner.frame(panelSize: CGSize(width: 430, height: 72), pointer: NSEvent.mouseLocation, screens: screens, anchor: .screenCenter), display: true)
        feedback.orderFrontRegardless()
        feedbackPanel = feedback
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.feedbackPanel?.orderOut(nil)
        }
    }

    private func resizeForPreview() {
        guard let panel, panel.isVisible else { return }
        guard let visible = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
        let height = min(standardPanelHeight + (state.isPreviewVisible ? 231 : 0), visible.height)
        var frame = panel.frame
        frame.origin.y = min(max(frame.maxY - height, visible.minY), visible.maxY - height)
        frame.size.height = height
        panel.setFrame(frame, display: true)
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
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if flags == .command, let characters = event.charactersIgnoringModifiers,
               let number = Int(characters), (1...9).contains(number) {
                _ = self.state.pasteResult(number: number)
                return nil
            }
            switch event.keyCode {
            case 126: self.state.moveSelection(by: -1); return nil
            case 125: self.state.moveSelection(by: 1); return nil
            case 53:
                if self.state.isPreviewVisible { self.state.closePreview() }
                else { self.state.send(.dismiss) }
                return nil
            case 49 where flags.isEmpty && self.state.resultsHaveKeyboardFocus:
                self.state.togglePreview(); return nil
            case 16 where flags == .command:
                self.state.togglePreview(); return nil
            case 36, 76:
                AppLogger.panel.notice("Paste key received")
                if flags.contains(.option) { self.state.send(.copyOnly) }
                else if flags.contains(.shift) { self.state.send(.pastePlainText) }
                else { self.state.send(.pasteOriginal) }
                return nil
            case 35 where flags.contains(.command): self.state.send(.togglePin); return nil
            case 43 where flags.contains(.command): self.state.send(.openSettings); return nil
            default:
                if !flags.contains(.command), !flags.contains(.control),
                   event.characters?.contains(where: { !$0.isWhitespace }) == true {
                    self.state.resultsHaveKeyboardFocus = false
                }
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
