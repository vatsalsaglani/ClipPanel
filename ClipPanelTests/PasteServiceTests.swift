import AppKit
import XCTest
@testable import ClipPanel

final class PasteServiceTests: XCTestCase {
    @MainActor
    func testPermissionFallbackRestoresAllItemsAndRepresentations() async throws {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        var consumed: Int?
        let service = fixture.service(permission: false, consume: { consumed = $0 })
        let result = await service.restoreAndPerform(record: fixture.record, mode: .original, destination: fixture.destination, settings: fixture.settings)
        assertCopied(result)
        XCTAssertEqual(consumed, fixture.board.changeCount)
        XCTAssertEqual(fixture.board.pasteboardItems?.count, 2)
        for (index, item) in fixture.payload.items.enumerated() {
            for representation in item.representations {
                XCTAssertEqual(fixture.board.pasteboardItems?[index].data(forType: .init(representation.typeIdentifier)), representation.data)
            }
        }
        XCTAssertNotNil(fixture.board.pasteboardItems?.first?.data(forType: ClipboardConstants.selfWriteMarker))
        XCTAssertEqual(fixture.postCount, 0)
    }

    @MainActor
    func testDisabledFallbackPreservesClipboardWhenPermissionOrDestinationIsUnavailable() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        fixture.settings.copyOnlyFallbackEnabled = false
        let originalChangeCount = fixture.board.changeCount
        let result = await fixture.service(permission: false).restoreAndPerform(record: fixture.record, mode: .original, destination: fixture.destination, settings: fixture.settings)
        guard case .failed = result else { return XCTFail("Expected unavailable permission to fail") }
        let unavailable = await fixture.service().restoreAndPerform(record: fixture.record, mode: .original, destination: nil, settings: fixture.settings)
        guard case .failed = unavailable else { return XCTFail("Expected missing destination to fail") }
        XCTAssertEqual(fixture.board.changeCount, originalChangeCount)
        XCTAssertEqual(fixture.board.string(forType: .string), "existing clipboard")
    }

    @MainActor
    func testExplicitCopyWorksWithoutPermissionOrFallbackAndDoesNotActivate() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        fixture.settings.copyOnlyFallbackEnabled = false
        let result = await fixture.service(permission: false).restoreAndPerform(record: fixture.record, mode: .copyOnly, destination: fixture.destination, settings: fixture.settings)
        XCTAssertEqual(result, .copiedOnly("Copied to clipboard"))
        XCTAssertEqual(fixture.activateCount, 0)
        XCTAssertEqual(fixture.postCount, 0)
    }

    @MainActor
    func testFocusChangeDuringDelayKeepsRestoredClipboardWithoutSendingEvents() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        fixture.settings.copyOnlyFallbackEnabled = false
        let service = fixture.service(sleep: { _ in fixture.frontmost = false })
        let result = await service.restoreAndPerform(record: fixture.record, mode: .original, destination: fixture.destination, settings: fixture.settings)
        assertCopied(result)
        XCTAssertEqual(fixture.board.string(forType: .string), "first")
        XCTAssertEqual(fixture.postCount, 0)
    }

    @MainActor
    func testExternalClipboardChangeDuringDelayDoesNotPasteOrOverwriteNewContent() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        let service = fixture.service(sleep: { _ in
            fixture.board.clearContents()
            fixture.board.setString("new external copy", forType: .string)
        })
        let result = await service.restoreAndPerform(record: fixture.record, mode: .original, destination: fixture.destination, settings: fixture.settings)
        guard case .failed = result else { return XCTFail("Expected changed clipboard to stop paste") }
        XCTAssertEqual(fixture.board.string(forType: .string), "new external copy")
        XCTAssertEqual(fixture.postCount, 0)
    }

    @MainActor
    func testEventFailureRetainsClipboardAndReportsManualPasteRecovery() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        let service = fixture.service(post: { false })
        let result = await service.restoreAndPerform(record: fixture.record, mode: .original, destination: fixture.destination, settings: fixture.settings)
        assertCopied(result)
        XCTAssertEqual(fixture.board.string(forType: .string), "first")
    }

    @MainActor
    func testSuccessfulPastePostsOnlyAfterDestinationActivation() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        fixture.frontmost = false
        let service = fixture.service(sleep: { _ in fixture.frontmost = true })
        let result = await service.restoreAndPerform(record: fixture.record, mode: .original, destination: fixture.destination, settings: fixture.settings)
        XCTAssertEqual(result, .pasted)
        XCTAssertEqual(fixture.activateCount, 1)
        XCTAssertEqual(fixture.postCount, 1)
    }

    @MainActor
    func testNewCopySupersedesAnOlderPasteWaitingForActivation() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        fixture.frontmost = false
        var service: PasteService!
        service = fixture.service(sleep: { _ in
            fixture.frontmost = true
            _ = service.copy(record: fixture.record)
        })
        let result = await service.restoreAndPerform(record: fixture.record, mode: .original, destination: fixture.destination, settings: fixture.settings)
        XCTAssertEqual(result, .superseded)
        XCTAssertEqual(fixture.postCount, 0)
        XCTAssertEqual(fixture.board.string(forType: .string), "first")
    }

    @MainActor
    func testNewPasteSupersedesAnOlderPasteDuringDelay() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        var firstDelay = true
        var service: PasteService!
        service = fixture.service(sleep: { _ in
            if firstDelay {
                firstDelay = false
                let newer = await service.restoreAndPerform(record: fixture.record, mode: .original, destination: fixture.destination, settings: fixture.settings)
                XCTAssertEqual(newer, .pasted)
            }
        })
        let older = await service.restoreAndPerform(record: fixture.record, mode: .original, destination: fixture.destination, settings: fixture.settings)
        XCTAssertEqual(older, .superseded)
        XCTAssertEqual(fixture.postCount, 1)
    }

    @MainActor
    func testReopeningPanelInvalidatesPendingPaste() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        var service: PasteService!
        service = fixture.service(sleep: { _ in service.cancelPendingPaste() })
        let result = await service.restoreAndPerform(record: fixture.record, mode: .original, destination: fixture.destination, settings: fixture.settings)
        XCTAssertEqual(result, .superseded)
        XCTAssertEqual(fixture.postCount, 0)
    }

    @MainActor
    func testPlainTextModeDropsRichTypesOnlyWhenExplicitlyRequested() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        let result = await fixture.service().restoreAndPerform(record: fixture.record, mode: .plainText, destination: fixture.destination, settings: fixture.settings)
        XCTAssertEqual(result, .pasted)
        XCTAssertEqual(fixture.board.pasteboardItems?.count, 1)
        XCTAssertEqual(fixture.board.string(forType: .string), "first")
        XCTAssertNil(fixture.board.data(forType: .html))
        XCTAssertNil(fixture.board.data(forType: .fileURL))
    }

    @MainActor
    func testUnavailablePlainTextRespectsFallbackAndPreservesOriginalBytes() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        let bytes = Data([0x89, 0x50, 0x4e, 0x47])
        let payload = ClipboardPayload(items: [.init(representations: [.init(typeIdentifier: NSPasteboard.PasteboardType.png.rawValue, data: bytes)])])
        let service = PasteService(pasteboard: fixture.board, hasPermission: { true }, postPaste: { XCTFail("Must not paste unavailable plain text"); return true }, payloadProvider: { _ in payload })
        fixture.settings.copyOnlyFallbackEnabled = false
        let changeCount = fixture.board.changeCount
        let denied = await service.restoreAndPerform(record: fixture.record, mode: .plainText, destination: fixture.destination, settings: fixture.settings)
        guard case .failed = denied else { return XCTFail("Expected unavailable plain text to fail with fallback off") }
        XCTAssertEqual(fixture.board.changeCount, changeCount)
        fixture.settings.copyOnlyFallbackEnabled = true
        let fallback = await service.restoreAndPerform(record: fixture.record, mode: .plainText, destination: fixture.destination, settings: fixture.settings)
        assertCopied(fallback)
        XCTAssertEqual(fixture.board.data(forType: .png), bytes)
        XCTAssertNil(fixture.board.string(forType: .string))
    }

    @MainActor
    func testCancelledDelayRetainsClipboardWithoutPosting() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        let result = await fixture.service(sleep: { _ in throw CancellationError() }).restoreAndPerform(record: fixture.record, mode: .original, destination: fixture.destination, settings: fixture.settings)
        assertCopied(result)
        XCTAssertEqual(fixture.postCount, 0)
        XCTAssertEqual(fixture.board.string(forType: .string), "first")
    }

    @MainActor
    func testQueueStopsWhenFocusChangesBeforePosting() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        let service = fixture.service(sleep: { _ in fixture.frontmost = false })
        let result = await service.pasteQueue(records: [fixture.record, fixture.record], destination: fixture.destination, settings: fixture.settings)
        assertCopied(result)
        XCTAssertEqual(fixture.postCount, 0)
        XCTAssertEqual(fixture.board.string(forType: .string), "first")
    }

    @MainActor
    func testQueueDoesNotReplaceClipboardAfterFocusChangesBetweenItems() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        var sleeps = 0
        var afterFirstWrite: Int?
        let service = fixture.service(sleep: { _ in
            sleeps += 1
            if sleeps == 2 {
                afterFirstWrite = fixture.board.changeCount
                fixture.frontmost = false
            }
        })
        let result = await service.pasteQueue(records: [fixture.record, fixture.record], destination: fixture.destination, settings: fixture.settings)
        assertCopied(result)
        XCTAssertEqual(fixture.postCount, 1)
        XCTAssertEqual(fixture.board.changeCount, afterFirstWrite)
    }

    @MainActor
    func testQueueDoesNotOverwriteExternalCopyWhileWaitingForActivation() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        fixture.frontmost = false
        let service = fixture.service(sleep: { _ in
            fixture.board.clearContents()
            fixture.board.setString("external copy", forType: .string)
            fixture.frontmost = true
        })
        let result = await service.pasteQueue(records: [fixture.record], destination: fixture.destination, settings: fixture.settings)
        guard case .failed = result else { return XCTFail("Expected queue to stop for external copy") }
        XCTAssertEqual(fixture.board.string(forType: .string), "external copy")
        XCTAssertEqual(fixture.postCount, 0)
    }

    @MainActor
    func testQueueHonorsDisabledFallbackBeforeAnyWrite() async {
        let fixture = Fixture()
        defer { fixture.cleanup() }
        fixture.settings.copyOnlyFallbackEnabled = false
        let changeCount = fixture.board.changeCount
        let result = await fixture.service(permission: false).pasteQueue(records: [fixture.record], destination: fixture.destination, settings: fixture.settings)
        guard case .failed = result else { return XCTFail("Expected queue fallback opt-out") }
        XCTAssertEqual(fixture.board.changeCount, changeCount)
    }

    @MainActor
    private func assertCopied(_ result: PasteResult, file: StaticString = #filePath, line: UInt = #line) {
        guard case .copiedOnly(let message) = result else { return XCTFail("Expected copy recovery, got \(result)", file: file, line: line) }
        XCTAssertTrue(message.hasPrefix("Copied—press Command-V to paste"), file: file, line: line)
    }
}

@MainActor
private final class Fixture {
    let board = NSPasteboard.withUniqueName()
    let suite = "ClipPanelPasteTests.\(UUID().uuidString)"
    let settings: SettingsStore
    let record: ClipboardRecord
    let payload = ClipboardPayload(items: [
        .init(representations: [
            .init(typeIdentifier: NSPasteboard.PasteboardType.string.rawValue, data: Data("first".utf8)),
            .init(typeIdentifier: NSPasteboard.PasteboardType.html.rawValue, data: Data("<b>first</b>".utf8))
        ]),
        .init(representations: [.init(typeIdentifier: NSPasteboard.PasteboardType.fileURL.rawValue, data: Data("file:///tmp/test-file".utf8))])
    ])
    var frontmost = true
    var activateCount = 0
    var postCount = 0

    init() {
        settings = SettingsStore(defaults: UserDefaults(suiteName: suite)!)
        settings.autoPasteEnabled = true
        record = ClipboardRecord(kind: .mixed, displayText: "fixture", searchText: "fixture", contentHash: "fixture", byteCount: 1, itemCount: 2, payloadData: Data())
        board.setString("existing clipboard", forType: .string)
    }

    var destination: PasteDestination {
        PasteDestination(isAvailable: { true }, activate: { self.activateCount += 1; return true }, isFrontmost: { self.frontmost })
    }

    func service(permission: Bool = true, consume: @escaping (Int) -> Void = { _ in }, sleep: @escaping (UInt64) async throws -> Void = { _ in }, post: (() -> Bool)? = nil) -> PasteService {
        PasteService(pasteboard: board, consumeSelfWrite: consume, hasPermission: { permission }, sleep: sleep,
                     postPaste: post ?? { self.postCount += 1; return true }, payloadProvider: { _ in self.payload })
    }

    func cleanup() {
        board.releaseGlobally()
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }
}
