import AppKit

@MainActor
final class PasteboardMonitor {
    private let captureService: ClipboardCaptureService
    private let store: ClipboardStore
    private let settings: SettingsStore
    private let permissions: PermissionService
    private var timer: Timer?
    private var observedChangeCount: Int

    init(captureService: ClipboardCaptureService, store: ClipboardStore, settings: SettingsStore, permissions: PermissionService, pasteboard: NSPasteboard = .general) {
        self.captureService = captureService
        self.store = store
        self.settings = settings
        self.permissions = permissions
        observedChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        observedChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(timeInterval: 0.35, target: self, selector: #selector(pollTimerFired(_:)), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }

    func setMonitoringEnabled(_ enabled: Bool) {
        observedChangeCount = NSPasteboard.general.changeCount
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

    private func poll() {
        guard settings.monitoringEnabled else { return }
        guard permissions.clipboardAccessState != .denied else {
            AppLogger.monitor.notice("Clipboard access is denied; monitor is inactive")
            return
        }
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        guard changeCount != observedChangeCount else { return }
        observedChangeCount = changeCount
        let source = SourceApplicationService.currentSource()
        switch captureService.capture(from: pasteboard, settings: settings, source: source) {
        case let .captured(candidate):
            do {
                _ = try store.upsert(candidate, historyLimit: settings.historyLimit)
                AppLogger.monitor.debug("Captured clipboard metadata")
            } catch {
                AppLogger.persistence.error("Clipboard persistence failed")
            }
        case let .ignored(reason):
            AppLogger.monitor.debug("Clipboard capture skipped: \(reason.rawValue, privacy: .public)")
        }
    }
}
