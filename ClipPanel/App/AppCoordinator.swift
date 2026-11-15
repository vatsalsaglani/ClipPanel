import AppKit
import SwiftData

@MainActor
final class AppCoordinator {
    let appState = AppState()
    let settings: SettingsStore
    let modelContainer: ModelContainer
    let clipboardStore: ClipboardStore
    let pasteboardMonitor: PasteboardMonitor
    private let panelState = ClipboardPanelState()
    private let shortcutService = GlobalShortcutService()
    private let permissionService = PermissionService()
    private let caretService = AccessibilityCaretService()
    private let pasteService: PasteService
    private let launchAtLoginService = LaunchAtLoginService()
    private let onboardingController = OnboardingPanelController()
    private let libraryController = LibraryWindowController()
    private var historyMaintenanceTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private lazy var panelController = ClipboardPanelController(
        state: panelState,
        recordsProvider: { [weak self] in
            guard let self else { return [] }
            return (try? self.clipboardStore.searchItems()) ?? []
        },
        panelAnchorProvider: { [weak self] in self?.settings.panelAnchor ?? .mousePointer },
        panelDensityProvider: { [weak self] in self?.settings.panelDensity ?? .comfortable },
        keepSearchQueryProvider: { [weak self] in self?.settings.keepSearchQuery ?? false },
        caretPointProvider: { [weak self] in self?.caretService.caretPoint() }
    )

    init() {
        let container: ModelContainer
        if AppRuntime.isRunningTests {
            do {
                container = try ModelContainer(
                    for: Schema(ClipboardSchemaV2.models),
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
            } catch {
                fatalError("ClipPanel could not create the isolated test store.")
            }
        } else {
            do {
                container = try ModelContainer(
                    for: Schema(ClipboardSchemaV2.models),
                    migrationPlan: ClipboardMigrationPlan.self
                )
            } catch {
                // P0 builds shipped an inferred, unversioned store. SwiftData cannot put that store
                // directly into a staged migration chain, but it can perform the same additive
                // lightweight migration when opening the current schema directly.
                do {
                    container = try ModelContainer(for: Schema(ClipboardSchemaV2.models))
                } catch {
                    fatalError("ClipPanel could not create local history storage: \(error.localizedDescription)")
                }
            }
        }
        modelContainer = container
        settings = SettingsStore(defaults: AppRuntime.isRunningTests
            ? UserDefaults(suiteName: "ClipPanel.TestHost.\(UUID().uuidString)")!
            : .standard)
        clipboardStore = ClipboardStore(
            modelContext: ModelContext(container),
            vault: AppRuntime.isRunningTests ? try! EncryptedPayloadVault(keyData: Data(repeating: 0, count: 32)) : nil
        )
        pasteboardMonitor = PasteboardMonitor(
            captureService: ClipboardCaptureService(),
            store: clipboardStore,
            settings: settings,
            permissions: permissionService
        )
        pasteService = PasteService(
            monitor: pasteboardMonitor,
            permissions: permissionService,
            payloadProvider: { [clipboardStore] record in
                return try clipboardStore.payload(for: record)
            }
        )
        updateMonitoringStatus()
        settings.onMonitoringChanged = { [weak self] enabled in
            self?.pasteboardMonitor.setMonitoringEnabled(enabled)
            self?.updateMonitoringStatus()
        }
        settings.onRetentionChanged = { [weak self] in self?.maintainHistory() }
        settings.onDockIconVisibilityChanged = { visible in
            NSApp.setActivationPolicy(visible ? .regular : .accessory)
        }
        appState.onShowClipboard = { [weak self] in self?.showClipboard() }
        appState.onShowLibrary = { [weak self] in self?.showLibrary() }
        appState.onPauseMonitoring = { [weak self] duration in self?.settings.pauseMonitoring(for: duration) }
        appState.onToggleMonitoring = { [weak self] in self?.toggleMonitoring() }
        appState.onClearUnpinned = { [weak self] in self?.clearUnpinnedHistory() }
        appState.onClearAll = { [weak self] in self?.clearAllHistory() }
        appState.onRequestAutoPaste = { [weak self] in self?.requestAutoPaste() }
        appState.onRequestAccessibility = { [weak self] in self?.requestAccessibility() }
        appState.onOpenDataFolder = { [weak self] in self?.openDataFolder() }
        appState.onResetSettings = { [weak self] in self?.resetSettings() }
        ClipPanelAutomationRouter.shared.onRoute = { [weak self] route in self?.handleAutomationRoute(route) }
        // The panel searches its prepared value snapshot as the user types. Fetching history
        // here would decode image/file payloads and rebuild normalized fields every key.
        panelState.previewProvider = { [weak self] id in
            guard let self, let record = try? self.clipboardStore.record(id: id) else { return nil }
            return try? self.clipboardStore.payload(for: record)
        }
        panelState.onIntent = { [weak self] intent in self?.handlePanelIntent(intent) }
    }

    func start() {
        AppLogger.lifecycle.info("ClipPanel launched")
        AppLogger.permissions.notice("Auto-paste access granted: \(self.permissionService.autoPasteState == .granted); enabled: \(self.settings.autoPasteEnabled)")
        guard !AppRuntime.isRunningTests else {
            AppLogger.lifecycle.debug("Skipping menu-bar services under XCTest")
            return
        }
        settings.resumeMonitoringIfNeeded()
        maintainHistory()
        historyMaintenanceTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.maintainHistory() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.settings.resumeMonitoringIfNeeded()
                self?.maintainHistory()
            }
        }
        if settings.monitoringEnabled { pasteboardMonitor.start() }
        shortcutService.register { [weak self] in self?.showClipboard() }
        if settings.launchAtLogin { try? launchAtLoginService.setEnabled(true) }
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
        if !settings.onboardingCompleted {
            onboardingController.show(settings: settings, permissionService: permissionService) { [weak self] in
                self?.appState.hasCompletedOnboarding = true
                self?.appState.isMonitoring = self?.settings.monitoringEnabled ?? false
                if let enabled = self?.settings.launchAtLogin { try? self?.launchAtLoginService.setEnabled(enabled) }
            }
        }
    }

    func stop() {
        pasteboardMonitor.stop()
        historyMaintenanceTimer?.invalidate()
        historyMaintenanceTimer = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        AppLogger.lifecycle.info("ClipPanel terminating")
    }

    func showClipboard() {
        panelController.toggle()
    }

    func showLibrary() {
        pasteService.cancelPendingPaste()
        libraryController.show(
            store: clipboardStore,
            onCopy: { [weak self] id in self?.copyLibraryRecord(id) },
            onTransform: { [weak self] id, transformation in self?.transformLibraryRecord(id, using: transformation) },
            onPasteQueue: { [weak self] ids in self?.pasteLibraryQueue(ids) }
        )
    }

    private func toggleMonitoring() {
        settings.monitoringEnabled.toggle()
    }

    private func updateMonitoringStatus() {
        appState.isMonitoring = settings.monitoringEnabled
        appState.monitoringPausedUntil = settings.monitoringPausedUntil
        if let deadline = settings.monitoringPausedUntil {
            appState.statusMessage = "Monitoring paused until \(deadline.formatted(date: .omitted, time: .shortened))"
        } else {
            appState.statusMessage = settings.monitoringEnabled ? "Monitoring clipboard history" : "Monitoring paused"
        }
    }

    private func maintainHistory() {
        do {
            let removed = try clipboardStore.enforceRetention(limit: settings.historyLimit, maximumAgeDays: settings.historyMaximumAgeDays)
            if removed > 0 { refreshPanelResults(query: panelState.query) }
        } catch {
            AppLogger.persistence.error("History retention cleanup failed")
        }
    }

    private func clearUnpinnedHistory() {
        try? clipboardStore.clearUnpinned()
        refreshPanelResults(query: panelState.query)
    }

    private func clearAllHistory() {
        try? clipboardStore.clearAll()
        refreshPanelResults(query: panelState.query)
    }

    private func requestAutoPaste() {
        appState.statusMessage = permissionService.requestAutoPasteAccess(openSettingsIfNeeded: true) == .granted ? "Auto-paste permission is available" : "Enable this copy of ClipPanel in macOS Settings. If it is already enabled, remove the old entry and add the running app again, then quit and reopen ClipPanel."
    }

    private func requestAccessibility() {
        appState.statusMessage = caretService.requestAccess()
            ? "Accessibility permission is available"
            : "Grant Accessibility permission to anchor ClipPanel at the text caret"
    }

    func handleExternalURL(_ url: URL) {
        ClipPanelAutomationRouter.shared.handle(url: url)
    }

    private func handleAutomationRoute(_ route: ClipPanelAutomationRoute) {
        switch route {
        case .showClipboard(let query):
            panelController.show(query: query ?? "")
        case .openLibrary:
            showLibrary()
        }
    }

    private func openDataFolder() {
        guard let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        NSWorkspace.shared.open(folder)
    }

    private func resetSettings() {
        settings.reset()
        appState.isMonitoring = false
        appState.statusMessage = "Settings reset; monitoring paused"
    }

    private func refreshPanelResults(query: String) {
        let items = (try? clipboardStore.searchItems()) ?? []
        panelState.setSourceItems(items)
    }

    private func handlePanelIntent(_ intent: PanelIntent) {
        switch intent {
        case .dismiss:
            panelController.dismiss()
        case .togglePin:
            guard let item = panelState.selectedItem,
                  let record = try? clipboardStore.record(id: item.id) else { return }
            try? clipboardStore.setPinned(record, isPinned: !record.isPinned)
            refreshPanelResults(query: panelState.query)
        case .deleteSelection:
            guard let item = panelState.selectedItem,
                  let record = try? clipboardStore.record(id: item.id) else { return }
            if record.isPinned {
                panelState.statusMessage = "Pinned items must be unpinned before deletion."
            } else {
                try? clipboardStore.delete(record)
                refreshPanelResults(query: panelState.query)
            }
        case .pasteOriginal, .pastePlainText, .copyOnly:
            AppLogger.paste.notice("Paste intent received")
            guard let item = panelState.selectedItem,
                  let record = try? clipboardStore.record(id: item.id) else {
                panelState.statusMessage = "Select a clipboard item to paste."
                AppLogger.paste.notice("Paste stopped: no available selection")
                return
            }
            let mode: PasteMode = switch intent {
            case .pastePlainText: .plainText
            case .copyOnly: .copyOnly
            default: .original
            }
            if case .copyOnly = mode {
                // Copy-only never needs the post-event permission.
            } else if settings.autoPasteEnabled, permissionService.autoPasteState != .granted {
                // The explicit paste action may request permission, but PasteService
                // decides whether the user's copy fallback preference allows recovery.
                _ = permissionService.requestAutoPasteAccess()
            }
            let destination = panelController.priorApplication
            Task { @MainActor [weak self] in
                guard let self else { return }
                let result = await pasteService.restoreAndPerform(
                    record: record,
                    mode: mode,
                    previousApplication: destination,
                    settings: settings,
                    onRestored: { self.panelController.dismiss() }
                )
                switch result {
                case .failed(let message):
                    AppLogger.paste.notice("Paste did not complete")
                    panelState.statusMessage = message
                    appState.statusMessage = message
                case .superseded:
                    break
                case .pasted:
                    AppLogger.paste.notice("Paste events posted")
                    try? clipboardStore.markPasted(record)
                case .copiedOnly(let message):
                    AppLogger.paste.notice("Paste completed with copy-only fallback")
                    try? clipboardStore.markPasted(record)
                    appState.statusMessage = message
                    panelState.statusMessage = message
                }
            }
        case .openSettings:
            panelController.dismiss()
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    private func copyLibraryRecord(_ id: UUID) {
        guard let record = try? clipboardStore.record(id: id) else { return }
        switch pasteService.copy(record: record) {
        case .superseded:
            break
        case .failed(let message):
            appState.statusMessage = message
        case .copiedOnly(let message):
            try? clipboardStore.markPasted(record)
            appState.statusMessage = message
        case .pasted:
            try? clipboardStore.markPasted(record)
            appState.statusMessage = "Copied to clipboard"
        }
    }

    private func transformLibraryRecord(_ id: UUID, using transformation: ClipboardTextTransformation) {
        guard let record = try? clipboardStore.record(id: id) else { return }
        do {
            guard try clipboardStore.createTransformedRecord(from: record, transformation: transformation) != nil else {
                appState.statusMessage = "This clip has no text to transform."
                return
            }
            appState.statusMessage = "Created transformed copy"
            showLibrary()
        } catch {
            appState.statusMessage = "ClipPanel could not create the transformed copy."
        }
    }

    private func pasteLibraryQueue(_ ids: [UUID]) {
        let records = ids.compactMap { try? clipboardStore.record(id: $0) }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await pasteService.pasteQueue(records: records, previousApplication: libraryController.priorApplication, settings: settings)
            switch result {
            case .superseded:
                break
            case .pasted:
                records.forEach { try? clipboardStore.markPasted($0) }
                appState.statusMessage = "Pasted \(records.count) queued clips"
            case .copiedOnly(let message), .failed(let message):
                appState.statusMessage = message
            }
        }
    }
}
