import AppKit
import XCTest
@testable import ClipPanel

final class SearchPanelInteractionTests: XCTestCase {
    func testFuzzyHighlightsMatchScatteredCharactersAndIgnoreFilterSyntax() {
        let value = "Café release notes"
        let ranges = SearchEngine.displayMatchRanges(query: "type:text crn app:xcode", in: value)
        XCTAssertEqual(ranges.map { String(value[$0]) }, ["C", "r", "n"])
        XCTAssertTrue(SearchEngine.displayMatchRanges(query: "type:text app:cafe", in: value).isEmpty)
    }

    func testHighlightsAllOccurrencesAndKeepsUnicodeCharacterBoundaries() {
        let value = "Ｃafé café 👩🏽‍💻"
        let ranges = SearchEngine.displayMatchRanges(query: "cafe", in: value)
        XCTAssertEqual(ranges.map { String(value[$0]) }, ["Ｃafé", "café"])
    }

    func testFuzzyRankingPrefersCompactMatchesAndSubstringOverFuzzy() {
        let compact = item("alpha beta code", date: 1)
        let scattered = item("a long phrase before beta and another phrase before code", date: 2)
        let literal = item("abc reference", date: 3)
        XCTAssertEqual(SearchEngine.search("abc", in: [scattered, compact, literal]).map(\.id), [literal.id, compact.id, scattered.id])
    }

    @MainActor
    func testNumberShortcutsPasteDisplayedFilteredResultsAndIgnoreMissingNumbers() {
        let text = item("a text", date: 3)
        let firstImage = item("first image", date: 2, kind: .image)
        let secondImage = item("second image", date: 1, kind: .image)
        let state = ClipboardPanelState()
        var pastedID: UUID?
        state.onIntent = { _ in pastedID = state.selectedID }
        state.begin(items: [text, firstImage, secondImage])
        state.typeFilter = .images
        XCTAssertTrue(state.pasteResult(number: 2))
        XCTAssertEqual(pastedID, secondImage.id)
        XCTAssertFalse(state.pasteResult(number: 3))
        XCTAssertFalse(state.pasteResult(number: 0))
        XCTAssertFalse(state.pasteResult(number: 10))
        XCTAssertEqual(state.selectedID, secondImage.id)
    }

    @MainActor
    func testTextFilterIncludesRichTextAndURLsAndCombinesWithQuery() {
        let text = item("release text", kind: .text)
        let rich = item("release rich", kind: .richText)
        let url = item("release url", kind: .url)
        let image = item("release screenshot", kind: .image)
        let other = item("other text", kind: .text)
        let state = ClipboardPanelState()
        state.begin(items: [text, rich, url, image, other])
        state.query = "release"
        state.typeFilter = .text
        XCTAssertEqual(Set(state.results.map(\.id)), Set([text.id, rich.id, url.id]))
    }

    @MainActor
    func testSelectionClampsAndReconcilesWhenResultsChange() {
        let first = item("first", date: 2)
        let second = item("second", date: 1)
        let state = ClipboardPanelState()
        state.begin(items: [first, second])
        state.moveSelection(by: -1)
        XCTAssertEqual(state.selectedID, first.id)
        XCTAssertTrue(state.resultsHaveKeyboardFocus)
        state.moveSelection(by: 100)
        XCTAssertEqual(state.selectedID, second.id)
        state.query = "first"
        XCTAssertEqual(state.selectedID, first.id)
        XCTAssertFalse(state.resultsHaveKeyboardFocus)
        state.query = "absent"
        XCTAssertNil(state.selectedID)
    }

    @MainActor
    func testPreviewLoadsOnlyExplicitSelectionAndBoundsLongText() {
        let first = item("first", date: 2)
        let second = item("second", date: 1)
        let state = ClipboardPanelState()
        var loads: [UUID] = []
        state.previewProvider = { id in
            loads.append(id)
            return ClipboardPayload(items: [ClipboardPayloadItem(representations: [
                ClipboardRepresentation(typeIdentifier: NSPasteboard.PasteboardType.string.rawValue,
                                        data: Data(("line one\n" + String(repeating: "x", count: 120_000)).utf8))
            ])])
        }
        state.begin(items: [first, second])
        state.moveSelection(by: 1)
        XCTAssertTrue(loads.isEmpty)
        state.togglePreview()
        XCTAssertEqual(loads, [second.id])
        XCTAssertEqual(state.preview?.text?.count, ClipboardQuickPreview.textLimit)
        XCTAssertTrue(state.preview?.text?.contains("\n") == true)
        XCTAssertTrue(state.preview?.isTextTruncated == true)
        state.setResults([second, first])
        XCTAssertEqual(loads.count, 1, "Unchanged selected payload should not be decoded again")
        state.select(first.id)
        XCTAssertEqual(loads, [second.id, first.id])
        state.closePreview()
        XCTAssertNil(state.preview)
    }

    @MainActor
    func testPreviewDownsamplesLargeImages() throws {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2_400, pixelsHigh: 1_600,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let payload = ClipboardPayload(items: [ClipboardPayloadItem(representations: [
            ClipboardRepresentation(typeIdentifier: NSPasteboard.PasteboardType.png.rawValue, data: png)
        ])])
        let started = ContinuousClock.now
        let preview = ClipboardQuickPreview(item: item("Image", kind: .image), payload: payload)
        XCTAssertLessThan(started.duration(to: .now), .milliseconds(200))
        let image = try XCTUnwrap(preview.image)
        var rect = CGRect.zero
        let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: &rect, context: nil, hints: nil))
        XCTAssertLessThanOrEqual(max(cgImage.width, cgImage.height), ClipboardQuickPreview.imagePixelLimit)
    }

    func testPreparedSearchOverFiveThousandRecordsMeetsTypingBudget() {
        let items = (0..<5_000).map { index in
            ClipboardSearchItem(id: UUID(), kind: .text, displayText: "Clipboard note \(index)",
                searchText: index == 4_777 ? "release checklist target" : "Meeting notes \(index) " + String(repeating: "planning detail ", count: 12),
                sourceApplicationName: "TextEdit", lastCopiedAt: Date(timeIntervalSince1970: Double(index)), isPinned: false)
        }
        let index = SearchEngine.Index(items: items)
        _ = index.search("release") // warm caches before measuring a keypress
        let started = ContinuousClock.now
        let results = index.search("release target")
        let elapsed = started.duration(to: .now)
        XCTAssertEqual(results.map(\.id), [items[4_777].id])
        XCTAssertLessThan(elapsed, .milliseconds(150))
    }

    private func item(_ text: String, date: TimeInterval = 1, kind: ClipboardKind = .text) -> ClipboardSearchItem {
        ClipboardSearchItem(id: UUID(), kind: kind, displayText: text, searchText: text,
            sourceApplicationName: nil, lastCopiedAt: Date(timeIntervalSince1970: date), isPinned: false)
    }
}
