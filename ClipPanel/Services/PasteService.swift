import AppKit
import CoreGraphics

enum PasteMode: Sendable {
    case original
    case plainText
    case copyOnly
}

enum PasteResult: Equatable {
    case pasted
    case copiedOnly(String)
    case failed(String)
    /// A newer copy/paste owns the clipboard and its feedback now.
    case superseded
}

/// Main-actor closures keep application/focus observations live across suspension points.
@MainActor
struct PasteDestination {
    var isAvailable: () -> Bool
    var activate: () -> Bool
    var isFrontmost: () -> Bool

    init(isAvailable: @escaping () -> Bool, activate: @escaping () -> Bool, isFrontmost: @escaping () -> Bool) {
        self.isAvailable = isAvailable
        self.activate = activate
        self.isFrontmost = isFrontmost
    }

    init(application: NSRunningApplication) {
        isAvailable = { !application.isTerminated && application.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        activate = { application.activate() }
        isFrontmost = {
            application.isActive && NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier
        }
    }
}

@MainActor
final class PasteService {
    private let pasteboard: NSPasteboard
    private let consumeSelfWrite: (Int) -> Void
    private let hasPermission: () -> Bool
    private let sleep: (UInt64) async throws -> Void
    private let postPaste: () -> Bool
    private let payloadProvider: (ClipboardRecord) throws -> ClipboardPayload
    private var operationID = UUID()

    convenience init(
        monitor: PasteboardMonitor,
        permissions: PermissionService,
        payloadProvider: @escaping (ClipboardRecord) throws -> ClipboardPayload
    ) {
        self.init(
            pasteboard: .general,
            consumeSelfWrite: { monitor.consumeSelfWrite(changeCount: $0) },
            hasPermission: { permissions.autoPasteState == .granted },
            payloadProvider: payloadProvider
        )
    }

    /// Injectable boundaries allow recovery/race tests without touching the user's clipboard or apps.
    init(
        pasteboard: NSPasteboard,
        consumeSelfWrite: @escaping (Int) -> Void = { _ in },
        hasPermission: @escaping () -> Bool,
        sleep: @escaping (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) },
        postPaste: @escaping () -> Bool = { PasteService.postCommandV() },
        payloadProvider: @escaping (ClipboardRecord) throws -> ClipboardPayload
    ) {
        self.pasteboard = pasteboard
        self.consumeSelfWrite = consumeSelfWrite
        self.hasPermission = hasPermission
        self.sleep = sleep
        self.postPaste = postPaste
        self.payloadProvider = payloadProvider
    }

    func restoreAndPerform(
        record: ClipboardRecord,
        mode: PasteMode,
        previousApplication: NSRunningApplication?,
        settings: SettingsStore,
        onRestored: () -> Void = {}
    ) async -> PasteResult {
        await restoreAndPerform(record: record, mode: mode,
                                destination: previousApplication.map(PasteDestination.init(application:)),
                                settings: settings, onRestored: onRestored)
    }

    func restoreAndPerform(
        record: ClipboardRecord,
        mode: PasteMode,
        destination: PasteDestination?,
        settings: SettingsStore,
        onRestored: () -> Void = {}
    ) async -> PasteResult {
        let id = beginOperation()
        guard let payload = try? payloadProvider(record) else {
            return .failed("The saved clipboard item could not be decoded.")
        }
        let reason: String?
        if mode == .copyOnly {
            reason = nil
        } else if mode == .plainText, PreviewBuilder.text(from: payload) == nil {
            reason = "This item has no plain-text representation."
        } else {
            reason = unavailableReason(destination: destination, settings: settings)
        }
        // An opted-out fallback must not silently replace the current clipboard.
        if mode != .copyOnly, let reason, !settings.copyOnlyFallbackEnabled {
            return .failed("Auto-paste is unavailable. \(reason) Use Copy to copy this item.")
        }
        guard restore(payload: payload, sourceBundleIdentifier: record.sourceBundleIdentifier, mode: mode) else {
            return .failed("ClipPanel could not restore this clipboard item.")
        }
        let changeCount = pasteboard.changeCount
        onRestored()
        if mode == .copyOnly { return .copiedOnly("Copied to clipboard") }
        if let reason { return copiedFallback(reason) }
        guard let destination else { return copiedFallback("The previous app is unavailable.") }
        guard await activateDestination(destination, operation: id) else {
            return recovery(operation: id, changeCount: changeCount, reason: "ClipPanel could not reactivate the previous app.")
        }
        do { try await sleep(delay(settings)) }
        catch { return recovery(operation: id, changeCount: changeCount, reason: "Auto-paste was cancelled.") }
        return deliver(destination: destination, operation: id, changeCount: changeCount)
    }

    func copy(record: ClipboardRecord) -> PasteResult {
        _ = beginOperation()
        return copyPayload(record: record)
    }

    func pasteQueue(
        records: [ClipboardRecord],
        previousApplication: NSRunningApplication?,
        settings: SettingsStore
    ) async -> PasteResult {
        await pasteQueue(records: records, destination: previousApplication.map(PasteDestination.init(application:)), settings: settings)
    }

    func pasteQueue(records: [ClipboardRecord], destination: PasteDestination?, settings: SettingsStore) async -> PasteResult {
        let id = beginOperation()
        let initialChangeCount = pasteboard.changeCount
        guard let last = records.last else { return .failed("Add clips to the paste queue first.") }
        if let reason = unavailableReason(destination: destination, settings: settings) {
            guard settings.copyOnlyFallbackEnabled else { return .failed("Auto-paste is unavailable. \(reason) Use Copy to copy a queued item.") }
            switch copyPayload(record: last) {
            case .copiedOnly: return copiedFallback("\(reason) The final queued item was copied.")
            case let result: return result
            }
        }
        guard let destination else { return .failed("The previous app is unavailable.") }
        guard await activateDestination(destination, operation: id) else {
            guard id == operationID else { return .superseded }
            guard !Task.isCancelled, pasteboard.changeCount == initialChangeCount else {
                return .failed("The clipboard changed or the paste queue was cancelled; no queued items were copied.")
            }
            guard settings.copyOnlyFallbackEnabled else { return .failed("ClipPanel could not reactivate the previous app.") }
            switch copyPayload(record: last) {
            case .copiedOnly: return copiedFallback("ClipPanel could not reactivate the previous app. The final queued item was copied.")
            case let result: return result
            }
        }

        guard pasteboard.changeCount == initialChangeCount else {
            return .failed("The clipboard changed; the paste queue stopped before copying an item.")
        }
        var lastChangeCount: Int?
        for (index, record) in records.enumerated() {
            guard id == operationID else { return .superseded }
            guard !Task.isCancelled, destination.isAvailable(), destination.isFrontmost(), hasPermission() else {
                if let lastChangeCount { return recovery(operation: id, changeCount: lastChangeCount, reason: "The paste queue stopped because the destination or permission changed.") }
                return .failed("The paste queue stopped before copying an item because the destination or permission changed.")
            }
            if let lastChangeCount, pasteboard.changeCount != lastChangeCount {
                return .failed("The clipboard changed; the paste queue stopped. Select the next item to retry.")
            }
            guard let payload = try? payloadProvider(record),
                  restore(payload: payload, sourceBundleIdentifier: record.sourceBundleIdentifier, mode: .original) else {
                return .failed("ClipPanel could not restore a queued clipboard item.")
            }
            let changeCount = pasteboard.changeCount
            lastChangeCount = changeCount
            do { try await sleep(delay(settings)) }
            catch { return recovery(operation: id, changeCount: changeCount, reason: "The paste queue was cancelled.") }
            let result = deliver(destination: destination, operation: id, changeCount: changeCount)
            guard result == .pasted else { return result }
            if index == records.count - 1 { return .pasted }
            // Give the destination time to read this item before replacing the clipboard.
            do { try await sleep(delay(settings)) }
            catch { return recovery(operation: id, changeCount: changeCount, reason: "The paste queue was cancelled.") }
        }
        return id == operationID ? .pasted : .superseded
    }

    /// Presenting another panel cancels the intent to send a delayed keystroke.
    func cancelPendingPaste() {
        _ = beginOperation()
    }

    private func beginOperation() -> UUID {
        operationID = UUID()
        return operationID
    }

    private func unavailableReason(destination: PasteDestination?, settings: SettingsStore) -> String? {
        if !settings.autoPasteEnabled { return "Auto-paste is turned off." }
        if !hasPermission() { return "Enable ClipPanel in macOS Accessibility settings to use auto-paste." }
        if destination?.isAvailable() != true { return "The previous app is no longer available." }
        return nil
    }

    private func delay(_ settings: SettingsStore) -> UInt64 {
        UInt64(SettingsValidation.pasteDelay(settings.pasteDelay) * 1_000_000_000)
    }

    private func copiedFallback(_ reason: String) -> PasteResult {
        .copiedOnly("Copied—press Command-V to paste. \(reason)")
    }

    private func recovery(operation: UUID, changeCount: Int, reason: String) -> PasteResult {
        guard operation == operationID else { return .superseded }
        guard pasteboard.changeCount == changeCount else {
            return .failed("The clipboard changed; auto-paste stopped. Select the item again to retry.")
        }
        // Once restored, preserve the item even if fallback was disabled: undoing the
        // clipboard write here could overwrite a new copy from another application.
        return copiedFallback(reason)
    }

    private func deliver(destination: PasteDestination, operation: UUID, changeCount: Int) -> PasteResult {
        guard operation == operationID else { return .superseded }
        guard !Task.isCancelled, destination.isAvailable(), destination.isFrontmost(), hasPermission() else {
            return recovery(operation: operation, changeCount: changeCount, reason: "The destination or auto-paste permission changed.")
        }
        guard pasteboard.changeCount == changeCount else {
            return .failed("The clipboard changed; auto-paste stopped. Select the item again to retry.")
        }
        guard postPaste() else { return copiedFallback("Command-V could not be sent.") }
        return .pasted
    }

    private func copyPayload(record: ClipboardRecord) -> PasteResult {
        guard let payload = try? payloadProvider(record) else { return .failed("The saved clipboard item could not be decoded.") }
        return restore(payload: payload, sourceBundleIdentifier: record.sourceBundleIdentifier, mode: .copyOnly)
            ? .copiedOnly("Copied to clipboard")
            : .failed("ClipPanel could not restore this clipboard item.")
    }

    @discardableResult
    private func restore(payload: ClipboardPayload, sourceBundleIdentifier: String?, mode: PasteMode) -> Bool {
        let items: [NSPasteboardItem]
        if mode == .plainText, let text = PreviewBuilder.text(from: payload) {
            let item = NSPasteboardItem()
            item.setString(text, forType: .string)
            items = [item]
        } else {
            items = payload.items.map { snapshot in
                let item = NSPasteboardItem()
                for representation in snapshot.representations {
                    item.setData(representation.data, forType: NSPasteboard.PasteboardType(representation.typeIdentifier))
                }
                return item
            }
        }
        guard !items.isEmpty, items.allSatisfy({ !$0.types.isEmpty }) else { return false }
        items[0].setData(Data([1]), forType: ClipboardConstants.selfWriteMarker)
        items[0].setString(sourceBundleIdentifier ?? "", forType: ClipboardConstants.sourceMarker)
        pasteboard.clearContents()
        guard pasteboard.writeObjects(items) else { return false }
        consumeSelfWrite(pasteboard.changeCount)
        return true
    }

    private func activateDestination(_ destination: PasteDestination, operation: UUID) async -> Bool {
        guard operation == operationID, !Task.isCancelled, destination.isAvailable(), destination.activate() else { return false }
        for _ in 0..<50 {
            guard operation == operationID, !Task.isCancelled, destination.isAvailable() else { return false }
            if destination.isFrontmost() { return true }
            do { try await sleep(20_000_000) }
            catch { return false }
        }
        return false
    }

    private static func postCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
