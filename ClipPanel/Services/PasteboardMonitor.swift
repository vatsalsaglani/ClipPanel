import AppKit

@MainActor
final class PasteboardMonitor {
    private let captureService: ClipboardCaptureService
    private let store: ClipboardStore
    private let settings: SettingsStore
    private let permissions: PermissionService
    private let pasteboard: NSPasteboard
    private let sourceProvider: @MainActor () -> SourceApplication?
    private let clipboardAccessProvider: (@MainActor () -> ClipboardAccessState)?
    private var timer: Timer?
    private var observedChangeCount: Int

    init(captureService: ClipboardCaptureService, store: ClipboardStore, settings: SettingsStore, permissions: PermissionService, pasteboard: NSPasteboard = .general, sourceProvider: (@MainActor () -> SourceApplication?)? = nil, clipboardAccessProvider: (@MainActor () -> ClipboardAccessState)? = nil) {
        self.captureService = captureService
        self.store = store
        self.settings = settings
        self.permissions = permissions
        self.pasteboard = pasteboard
        self.sourceProvider = sourceProvider ?? { SourceApplicationService.currentSource() }
        self.clipboardAccessProvider = clipboardAccessProvider
        observedChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        observedChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(timeInterval: 0.35, target: self, selector: #selector(pollTimerFired(_:)), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }

    func setMonitoringEnabled(_ enabled: Bool) {
        observedChangeCount = pasteboard.changeCount
        if enabled {
            start()
        } else {
            stop()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func consumeSelfWrite(changeCount: Int) {
        observedChangeCount = changeCount
    }

    @objc private func pollTimerFired(_ timer: Timer) {
        poll()
    }

    func poll() {
        guard settings.monitoringEnabled else { return }
        guard (clipboardAccessProvider?() ?? permissions.clipboardAccessState) != .denied else {
            AppLogger.monitor.notice("Clipboard access is denied; monitor is inactive")
            return
        }
        let changeCount = pasteboard.changeCount
        guard changeCount != observedChangeCount else { return }
        observedChangeCount = changeCount
        let source = sourceProvider()
        switch captureService.capture(from: pasteboard, settings: settings, source: source) {
        case let .captured(candidate):
            do {
                _ = try store.upsert(candidate, historyLimit: settings.historyLimit, maximumAgeDays: settings.historyMaximumAgeDays)
                AppLogger.monitor.debug("Captured clipboard metadata")
            } catch {
                AppLogger.persistence.error("Clipboard persistence failed")
            }
        case let .ignored(reason):
            AppLogger.monitor.debug("Clipboard capture skipped: \(reason.rawValue, privacy: .public)")
        }
    }
}
