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
}

@MainActor
final class PasteService {
    private let monitor: PasteboardMonitor
    private let permissions: PermissionService
    private let payloadProvider: (ClipboardRecord) throws -> ClipboardPayload

    init(
        monitor: PasteboardMonitor,
        permissions: PermissionService,
        payloadProvider: @escaping (ClipboardRecord) throws -> ClipboardPayload
    ) {
        self.monitor = monitor
        self.permissions = permissions
        self.payloadProvider = payloadProvider
    }

    func restoreAndPerform(
        record: ClipboardRecord,
        mode: PasteMode,
        previousApplication: NSRunningApplication?,
        settings: SettingsStore
    ) async -> PasteResult {
        guard let payload = try? payloadProvider(record) else {
            return .failed("The saved clipboard item could not be decoded.")
        }
        guard restore(payload: payload, sourceBundleIdentifier: record.sourceBundleIdentifier, mode: mode) else {
            return .failed("ClipPanel could not restore this clipboard item.")
        }
        if mode == .copyOnly { return .copiedOnly("Copied to clipboard") }
        if mode == .plainText, PreviewBuilder.text(from: payload) == nil {
            return .copiedOnly("This item has no plain-text representation; original content was copied.")
        }
        guard settings.autoPasteEnabled, permissions.autoPasteState == .granted else {
            return .copiedOnly("Copied to clipboard; auto-paste permission is unavailable.")
        }
        guard let previousApplication, !previousApplication.isTerminated else {
            return .copiedOnly("Copied to clipboard; the previous app is no longer available.")
        }
        guard previousApplication.activate() else {
            return .copiedOnly("Copied to clipboard; ClipPanel could not reactivate the previous app.")
        }
        let nanoseconds = UInt64(SettingsValidation.pasteDelay(settings.pasteDelay) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
        guard postCommandV() else {
            return .copiedOnly("Copied to clipboard; Command-V could not be sent.")
        }
        return .pasted
    }

    func copy(record: ClipboardRecord) -> PasteResult {
        guard let payload = try? payloadProvider(record) else {
            return .failed("The saved clipboard item could not be decoded.")
        }
        return restore(payload: payload, sourceBundleIdentifier: record.sourceBundleIdentifier, mode: .copyOnly)
            ? .copiedOnly("Copied to clipboard")
            : .failed("ClipPanel could not restore this clipboard item.")
    }

    func pasteQueue(
        records: [ClipboardRecord],
        previousApplication: NSRunningApplication?,
        settings: SettingsStore
    ) async -> PasteResult {
        guard !records.isEmpty else { return .failed("Add clips to the paste queue first.") }
        guard settings.autoPasteEnabled, permissions.autoPasteState == .granted else {
            guard let last = records.last else { return .failed("The paste queue is empty.") }
            switch copy(record: last) {
            case .failed:
                return .failed("ClipPanel could not restore the final queued item.")
            case .pasted, .copiedOnly:
                return .copiedOnly("Auto-paste is unavailable; the final queued item was copied.")
            }
        }
        guard let previousApplication, !previousApplication.isTerminated, previousApplication.activate() else {
            return .copiedOnly("The previous app is unavailable; no queued items were pasted.")
        }

        let nanoseconds = UInt64(SettingsValidation.pasteDelay(settings.pasteDelay) * 1_000_000_000)
        for record in records {
            guard !Task.isCancelled else { return .copiedOnly("Paste queue cancelled.") }
            guard let payload = try? payloadProvider(record),
                  restore(payload: payload, sourceBundleIdentifier: record.sourceBundleIdentifier, mode: .original) else {
                return .failed("ClipPanel could not restore a queued clipboard item.")
            }
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return .copiedOnly("Paste queue cancelled.") }
            guard postCommandV() else { return .copiedOnly("A queued item was copied, but Command-V could not be sent.") }
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
        return .pasted
    }

    @discardableResult
    private func restore(payload: ClipboardPayload, sourceBundleIdentifier: String?, mode: PasteMode) -> Bool {
        let pasteboard = NSPasteboard.general
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
        guard !items.isEmpty else { return false }
        items[0].setData(Data([1]), forType: ClipboardConstants.selfWriteMarker)
        items[0].setString(sourceBundleIdentifier ?? "", forType: ClipboardConstants.sourceMarker)
        pasteboard.clearContents()
        guard pasteboard.writeObjects(items) else { return false }
        monitor.consumeSelfWrite(changeCount: pasteboard.changeCount)
        return true
    }

    private func postCommandV() -> Bool {
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
