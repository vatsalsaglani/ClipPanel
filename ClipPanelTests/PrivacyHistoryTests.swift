import AppKit
import SwiftData
import XCTest
@testable import ClipPanel

final class PrivacyHistoryTests: XCTestCase {
    func testTimedPausePersistsAndResumesOnlyAtDeadline() async throws {
        try await MainActor.run {
            let suite = "ClipPanel.PrivacyTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let settings = SettingsStore(defaults: defaults)
            let now = Date().addingTimeInterval(10_000)
            settings.monitoringEnabled = true
            settings.pauseMonitoring(for: .fifteenMinutes, now: now)
            XCTAssertFalse(settings.monitoringEnabled)
            XCTAssertEqual(settings.monitoringPausedUntil, now.addingTimeInterval(900))
            let relaunched = SettingsStore(defaults: defaults)
            XCTAssertFalse(relaunched.monitoringEnabled)
            relaunched.resumeMonitoringIfNeeded(now: now.addingTimeInterval(899))
            XCTAssertFalse(relaunched.monitoringEnabled)
            relaunched.resumeMonitoringIfNeeded(now: now.addingTimeInterval(900))
            XCTAssertTrue(relaunched.monitoringEnabled)
            XCTAssertNil(relaunched.monitoringPausedUntil)
            settings.monitoringEnabled = false // Release the original instance's timer too.
        }
    }

    func testManualPauseCancelsDeadlineAndManualResumeClearsIt() async throws {
        try await MainActor.run {
            let suite = "ClipPanel.PrivacyTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let settings = SettingsStore(defaults: defaults)
            settings.pauseMonitoring(for: .oneHour)
            XCTAssertNil(settings.monitoringPausedUntil, "Timed pause cannot opt a disabled monitor into capture")
            settings.monitoringEnabled = true
            settings.pauseMonitoring(for: .oneHour)
            settings.monitoringEnabled = false
            XCTAssertNil(settings.monitoringPausedUntil)
            settings.resumeMonitoringIfNeeded(now: .distantFuture)
            XCTAssertFalse(settings.monitoringEnabled)
            settings.monitoringEnabled = true
            settings.pauseMonitoring(for: .fourHours)
            settings.resumeMonitoring()
            XCTAssertTrue(settings.monitoringEnabled)
            XCTAssertNil(settings.monitoringPausedUntil)
        }
    }

    func testExpiredPauseResumesOnRelaunchAndResetDisablesExpiry() async throws {
        try await MainActor.run {
            let suite = "ClipPanel.PrivacyTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            defaults.set(false, forKey: "monitoringEnabled")
            defaults.set(Date.distantPast, forKey: "monitoringPausedUntil")
            let settings = SettingsStore(defaults: defaults)
            XCTAssertTrue(settings.monitoringEnabled)
            XCTAssertNil(settings.monitoringPausedUntil)
            XCTAssertEqual(settings.historyMaximumAgeDays, 0)
            settings.historyMaximumAgeDays = 7
            settings.pauseMonitoring(for: .oneHour)
            settings.reset()
            XCTAssertEqual(settings.historyMaximumAgeDays, 0)
            XCTAssertFalse(settings.monitoringEnabled)
            XCTAssertNil(settings.monitoringPausedUntil)
        }
    }

    func testObservableNumericSettingsNormalizeWithoutRecursiveSetters() async throws {
        try await MainActor.run {
            let suite = "ClipPanel.PrivacyTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let settings = SettingsStore(defaults: defaults)
            var retentionChanges = 0
            settings.onRetentionChanged = { retentionChanges += 1 }
            settings.historyMaximumAgeDays = 7
            settings.historyLimit = 100
            settings.maximumPayloadBytes = 2 * 1_024 * 1_024
            settings.pasteDelay = 0.2
            XCTAssertEqual(retentionChanges, 2)
            settings.historyMaximumAgeDays = -1
            settings.historyLimit = 20_000
            settings.maximumPayloadBytes = 0
            settings.pasteDelay = .nan
            XCTAssertEqual(settings.historyMaximumAgeDays, 0)
            XCTAssertEqual(settings.historyLimit, SettingsValidation.historyRange.upperBound)
            XCTAssertEqual(settings.maximumPayloadBytes, SettingsValidation.payloadRange.lowerBound)
            XCTAssertEqual(settings.pasteDelay, 0.10)
            XCTAssertEqual(retentionChanges, 4, "Normalization emits one retention change per assignment")
            XCTAssertEqual(defaults.integer(forKey: "historyMaximumAgeDays"), 0)
            XCTAssertEqual(defaults.integer(forKey: "historyLimit"), SettingsValidation.historyRange.upperBound)
            XCTAssertEqual(defaults.integer(forKey: "maximumPayloadBytes"), SettingsValidation.payloadRange.lowerBound)
            XCTAssertEqual(defaults.double(forKey: "pasteDelay"), 0.10)
            let reloaded = SettingsStore(defaults: defaults)
            XCTAssertEqual(reloaded.historyLimit, settings.historyLimit)
            XCTAssertEqual(reloaded.maximumPayloadBytes, settings.maximumPayloadBytes)
            settings.reset()
            XCTAssertEqual(settings.historyMaximumAgeDays, 0)
            XCTAssertEqual(settings.historyLimit, 500)
            XCTAssertEqual(settings.maximumPayloadBytes, 20 * 1_024 * 1_024)
            XCTAssertEqual(settings.pasteDelay, 0.10)
            XCTAssertEqual(retentionChanges, 4, "Reset never triggers destructive history cleanup")
            settings.historyMaximumAgeDays = 30
            XCTAssertEqual(retentionChanges, 5, "Explicit retention edits still clean up after reset")
        }
    }

    func testAgeExpiryUsesLastCopyAndPreservesIntentionalLibraryItems() async throws {
        try await MainActor.run {
            let container = try ModelContainer(for: Schema(ClipboardSchemaV2.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let context = ModelContext(container)
            let vault = try EncryptedPayloadVault(keyData: Data(repeating: 17, count: 32))
            let store = ClipboardStore(modelContext: context, vault: vault)
            let now = Date(timeIntervalSince1970: 1_000_000)
            let old = now.addingTimeInterval(-10 * 86_400)
            let disposable = try store.upsert(privacyCandidate("old history"), historyLimit: 500, now: old)
            _ = try store.updateMetadata(recordID: disposable.id, note: "also removes associated metadata")
            let pin = try store.upsert(privacyCandidate("pin"), historyLimit: 500, now: old)
            try store.setPinned(pin, isPinned: true)
            let saved = try store.upsert(privacyCandidate("saved"), historyLimit: 500, now: old)
            _ = try store.updateMetadata(recordID: saved.id, isSavedSnippet: true)
            let favorite = try store.upsert(privacyCandidate("favorite"), historyLimit: 500, now: old)
            _ = try store.updateMetadata(recordID: favorite.id, isFavorite: true)
            let collection = try store.createCollection(named: "Library")
            let collected = try store.upsert(privacyCandidate("collected"), historyLimit: 500, now: old)
            _ = try store.updateMetadata(recordID: collected.id, collectionIDs: [collection.id])
            let encryptedCollection = try store.createCollection(named: "Encrypted", isEncrypted: true)
            let encrypted = try store.upsert(privacyCandidate("encrypted"), historyLimit: 500, now: old)
            _ = try store.updateMetadata(recordID: encrypted.id, collectionIDs: [encryptedCollection.id])
            let ciphertext = try XCTUnwrap(store.metadata(for: encrypted.id)?.encryptedPayloadData)
            let recent = try store.upsert(privacyCandidate("recopied"), historyLimit: 500, now: old)
            _ = try store.upsert(privacyCandidate("recopied"), historyLimit: 500, now: now)
            XCTAssertEqual(try store.enforceRetention(limit: 500, now: now), 0, "Expiry is off by default")
            XCTAssertEqual(try store.enforceRetention(limit: 500, maximumAgeDays: 7, now: now), 1)
            XCTAssertNil(try store.record(id: disposable.id))
            XCTAssertNil(try store.metadata(for: disposable.id))
            XCTAssertEqual(Set(try store.records().map(\.id)), [pin.id, saved.id, favorite.id, collected.id, encrypted.id, recent.id])
            XCTAssertEqual(try store.metadata(for: encrypted.id)?.encryptedPayloadData, ciphertext)
            XCTAssertTrue(encrypted.payloadData.isEmpty)
            XCTAssertEqual(try store.text(for: encrypted), "encrypted")
            XCTAssertEqual(try store.enforceRetention(limit: 0, maximumAgeDays: 7, now: now), 1)
            XCTAssertEqual(try store.records().count, 5, "Count cleanup also preserves deliberately saved items")
        }
    }

    func testPanelSearchSnapshotsSkipPayloadDetailsButLibraryKeepsThem() async throws {
        try await MainActor.run {
            let container = try ModelContainer(for: Schema(ClipboardSchemaV2.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let store = ClipboardStore(modelContext: ModelContext(container), vault: try EncryptedPayloadVault(keyData: Data(repeating: 19, count: 32)))
            let imageBytes = Data([1, 2, 3])
            let payload = ClipboardPayload(items: [ClipboardPayloadItem(representations: [ClipboardRepresentation(typeIdentifier: NSPasteboard.PasteboardType.png.rawValue, data: imageBytes)])])
            let capture = ClipboardCaptureCandidate(payload: payload, encodedPayload: try JSONEncoder().encode(payload), preview: ClipboardPreview(kind: .image, displayText: "Image", searchText: "image"), contentHash: ClipboardHasher.hash(payload: payload), source: nil)
            _ = try store.upsert(capture, historyLimit: 500)
            let searchItem = try XCTUnwrap(store.searchItems().first)
            XCTAssertNil(searchItem.thumbnailData)
            XCTAssertNil(searchItem.fileURL)
            XCTAssertEqual(try store.libraryItems().first?.record.thumbnailData, imageBytes)
        }
    }

    func testResumeDoesNotCapturePausedClipboardAndExclusionsSkipFutureCopies() async throws {
        try await MainActor.run {
            let suite = "ClipPanel.PrivacyTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let settings = SettingsStore(defaults: defaults)
            let container = try ModelContainer(for: Schema(ClipboardSchemaV2.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let store = ClipboardStore(modelContext: ModelContext(container), vault: try EncryptedPayloadVault(keyData: Data(repeating: 18, count: 32)))
            let pasteboard = NSPasteboard(name: .init("ClipPanel.PrivacyTests.\(UUID().uuidString)"))
            defer { pasteboard.releaseGlobally() }
            let monitor = PasteboardMonitor(captureService: ClipboardCaptureService(), store: store, settings: settings, permissions: PermissionService(), pasteboard: pasteboard, sourceProvider: { SourceApplication(bundleIdentifier: "test.fixture", name: "Fixture") }, clipboardAccessProvider: { .ready })
            defer { monitor.stop() }
            settings.onMonitoringChanged = { monitor.setMonitoringEnabled($0) }
            settings.monitoringEnabled = true
            pasteboard.clearContents()
            pasteboard.setString("before pause", forType: .string)
            monitor.poll()
            XCTAssertEqual(try store.records().count, 1)
            settings.pauseMonitoring(for: .fifteenMinutes)
            pasteboard.clearContents()
            pasteboard.setString("while paused", forType: .string)
            settings.resumeMonitoringIfNeeded(now: .distantFuture)
            monitor.poll()
            XCTAssertEqual(try store.records().count, 1)
            settings.ignoredBundleIdentifiers.insert("test.fixture")
            pasteboard.clearContents()
            pasteboard.setString("ignored copy", forType: .string)
            monitor.poll()
            XCTAssertEqual(try store.records().count, 1)
            settings.ignoredBundleIdentifiers.remove("test.fixture")
            pasteboard.clearContents()
            pasteboard.setString("after exclusion removed", forType: .string)
            monitor.poll()
            XCTAssertEqual(try store.records().count, 2)
        }
    }

}

private func privacyCandidate(_ text: String) -> ClipboardCaptureCandidate {
    let payload = ClipboardPayload(items: [ClipboardPayloadItem(representations: [ClipboardRepresentation(typeIdentifier: NSPasteboard.PasteboardType.string.rawValue, data: Data(text.utf8))])])
    return ClipboardCaptureCandidate(payload: payload, encodedPayload: try! JSONEncoder().encode(payload), preview: ClipboardPreview(kind: .text, displayText: text, searchText: text), contentHash: ClipboardHasher.hash(payload: payload), source: nil)
}
