import AppKit
import XCTest
@testable import ClipPanel

final class ClipboardTransformationTests: XCTestCase {
    @MainActor
    func testExtractURLsPreservesOrderAndRemovesDuplicates() {
        let payload = textPayload("Visit https://example.com/a?x=1 and https://example.org/docs. Again https://example.com/a?x=1")
        let result = ClipboardTransformationService.transform(payload, using: .extractURLs)
        XCTAssertEqual(result.flatMap(PreviewBuilder.text), "https://example.com/a?x=1\nhttps://example.org/docs")
        XCTAssertEqual(PreviewBuilder.text(from: payload), "Visit https://example.com/a?x=1 and https://example.org/docs. Again https://example.com/a?x=1")
    }

    @MainActor
    func testExtractURLsDoesNotReturnEmailsOrNonWebLinks() {
        XCTAssertNil(ClipboardTransformationService.transform(textPayload("person@example.com file:///tmp/test ssh://example.com"), using: .extractURLs))
        XCTAssertNil(ClipboardTransformationService.transform(textPayload("No links here"), using: .extractURLs))
    }

    @MainActor
    func testTextTransformProducesPlainTextWithoutMutatingRichOriginal() {
        let payload = ClipboardPayload(items: [ClipboardPayloadItem(representations: [
            ClipboardRepresentation(typeIdentifier: NSPasteboard.PasteboardType.string.rawValue, data: Data("  Mixed Case  ".utf8)),
            ClipboardRepresentation(typeIdentifier: NSPasteboard.PasteboardType.html.rawValue, data: Data("<b>  Mixed Case  </b>".utf8))
        ])])
        let result = ClipboardTransformationService.transform(payload, using: .trimWhitespace)
        XCTAssertEqual(result.flatMap(PreviewBuilder.text), "Mixed Case")
        XCTAssertEqual(result?.items.first?.representations.count, 1)
        XCTAssertEqual(payload.items.first?.representations.count, 2)
    }

    private func textPayload(_ value: String) -> ClipboardPayload {
        ClipboardPayload(items: [ClipboardPayloadItem(representations: [
            ClipboardRepresentation(typeIdentifier: NSPasteboard.PasteboardType.string.rawValue, data: Data(value.utf8))
        ])])
    }
}
