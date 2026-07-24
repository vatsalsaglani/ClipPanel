import XCTest
@testable import ClipPanel

final class SearchAndGeometryTests: XCTestCase {
    func testSearchFoldsDiacriticsAndPrefersPrefix() {
        let date = Date(timeIntervalSince1970: 10)
        let results = SearchEngine.search("cafe", in: [
            ClipboardSearchItem(id: UUID(), kind: .text, displayText: "decaf café", searchText: "decaf café", sourceApplicationName: nil, lastCopiedAt: date, isPinned: false),
            ClipboardSearchItem(id: UUID(), kind: .text, displayText: "Café notes", searchText: "Café notes", sourceApplicationName: nil, lastCopiedAt: date.addingTimeInterval(-1), isPinned: false)
        ])
        XCTAssertEqual(results.map(\.displayText), ["Café notes", "decaf café"])
    }

    func testRelativeTimeFormatterNeverShowsSeconds() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertEqual(RelativeTimeFormatter.string(since: now.addingTimeInterval(-45), now: now), "Now")
        XCTAssertEqual(RelativeTimeFormatter.string(since: now.addingTimeInterval(-2_085), now: now), "34 min")
        XCTAssertEqual(RelativeTimeFormatter.string(since: now.addingTimeInterval(-7_200), now: now), "2 hr")
    }

    func testSearchRequiresEveryTokenAndCanSearchSourceApplication() {
        let item = ClipboardSearchItem(id: UUID(), kind: .text, displayText: "deploy checklist", searchText: "deploy checklist", sourceApplicationName: "Xcode", lastCopiedAt: .now, isPinned: false)
        XCTAssertEqual(SearchEngine.search("xcode deploy", in: [item]), [item])
        XCTAssertTrue(SearchEngine.search("xcode missing", in: [item]).isEmpty)
    }

    func testSearchRanksVisibleTitleMatchesAboveNewerBodyMatches() {
        let titleMatch = ClipboardSearchItem(id: UUID(), kind: .text, displayText: "Report for July", searchText: "Report for July", sourceApplicationName: nil, lastCopiedAt: Date(timeIntervalSince1970: 1), isPinned: false)
        let bodyMatch = ClipboardSearchItem(id: UUID(), kind: .text, displayText: "Meeting notes", searchText: "Meeting notes with a report attached", sourceApplicationName: nil, lastCopiedAt: Date(timeIntervalSince1970: 2), isPinned: false)
        XCTAssertEqual(SearchEngine.search("report", in: [bodyMatch, titleMatch]).map(\.id), [titleMatch.id, bodyMatch.id])
    }

    func testSearchExcludesNonMatchingItems() {
        let match = ClipboardSearchItem(id: UUID(), kind: .text, displayText: "CODEARTIFACT token", searchText: "CODEARTIFACT token", sourceApplicationName: nil, lastCopiedAt: .now, isPinned: false)
        let nonMatch = ClipboardSearchItem(id: UUID(), kind: .image, displayText: "Image", searchText: "image", sourceApplicationName: "ChatGPT", lastCopiedAt: .now, isPinned: false)
        XCTAssertEqual(SearchEngine.search("CODEARTIFACT", in: [nonMatch, match]), [match])
    }

    func testDisplayMatchRangesFindsCaseAndDiacriticInsensitiveTerms() {
        let ranges = SearchEngine.displayMatchRanges(query: "cafe", in: "Café notes")
        XCTAssertEqual(ranges.map { String("Café notes"[$0]) }, ["Café"])
    }

    func testSearchOverOneThousandRecordsMeetsTarget() {
        let records = (0..<1_000).map { index in
            ClipboardSearchItem(
                id: UUID(),
                kind: .text,
                displayText: "Clipboard record \(index)",
                searchText: index == 777 ? "release checklist target" : "clipboard record \(index)",
                sourceApplicationName: index.isMultiple(of: 2) ? "Xcode" : "TextEdit",
                lastCopiedAt: Date(timeIntervalSince1970: TimeInterval(index)),
                isPinned: false
            )
        }
        let started = ContinuousClock.now
        let results = SearchEngine.search("release target", in: records)
        let elapsed = started.duration(to: .now)
        XCTAssertEqual(results.count, 1)
        XCTAssertLessThan(elapsed, .milliseconds(50))
    }

    func testPanelOpeningSelectsFirstResult() async {
        let result = await MainActor.run { () -> (UUID?, UUID) in
            let first = ClipboardSearchItem(id: UUID(), kind: .text, displayText: "first", searchText: "first", sourceApplicationName: nil, lastCopiedAt: Date(timeIntervalSince1970: 2), isPinned: false)
            let second = ClipboardSearchItem(id: UUID(), kind: .text, displayText: "second", searchText: "second", sourceApplicationName: nil, lastCopiedAt: Date(timeIntervalSince1970: 1), isPinned: false)
            let state = ClipboardPanelState()
            state.setResults([first, second])
            state.select(second.id)
            state.begin(results: [first, second])
            return (state.selectedID, first.id)
        }
        XCTAssertEqual(result.0, result.1)
    }

    func testPanelStateReordersImmediatelyWhenTheQueryChanges() async {
        let result = await MainActor.run { () -> [String] in
            let bodyMatch = ClipboardSearchItem(id: UUID(), kind: .text, displayText: "Notes", searchText: "A report is in the body", sourceApplicationName: nil, lastCopiedAt: Date(timeIntervalSince1970: 2), isPinned: false)
            let titleMatch = ClipboardSearchItem(id: UUID(), kind: .text, displayText: "Report", searchText: "Report", sourceApplicationName: nil, lastCopiedAt: Date(timeIntervalSince1970: 1), isPinned: false)
            let state = ClipboardPanelState()
            state.begin(items: [bodyMatch, titleMatch])
            state.query = "report"
            return state.results.map(\.displayText)
        }
        XCTAssertEqual(result, ["Report", "Notes"])
    }

    func testEmptySearchPlacesPinsBeforeRecency() {
        let oldPin = item("old pin", date: 1, pinned: true)
        let recent = item("recent", date: 3, pinned: false)
        let newPin = item("new pin", date: 2, pinned: true)
        XCTAssertEqual(SearchEngine.search("", in: [recent, oldPin, newPin]).map(\.displayText), ["new pin", "old pin", "recent"])
    }

    func testSmartSearchFiltersAndRegex() {
        let matching = ClipboardSearchItem(
            id: UUID(),
            kind: .image,
            displayText: "build-123 screenshot",
            searchText: "build-123 screenshot",
            sourceApplicationName: "Xcode",
            lastCopiedAt: .now,
            isPinned: false,
            tagNames: ["Release"],
            collectionNames: ["Work"],
            isSavedSnippet: true,
            isFavorite: true
        )
        let other = ClipboardSearchItem(id: UUID(), kind: .text, displayText: "note", searchText: "note", sourceApplicationName: "Notes", lastCopiedAt: .now, isPinned: false)
        XCTAssertEqual(SearchEngine.search("type:image app:xcode tag:release collection:work favorite snippet regex:build-[0-9]+", in: [other, matching]), [matching])
    }

    func testPanelPositionStaysInsideAllEdges() {
        let screen = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1_200, height: 800), visibleFrame: CGRect(x: 0, y: 24, width: 1_200, height: 746))
        for point in [CGPoint(x: 1, y: 25), CGPoint(x: 1_199, y: 25), CGPoint(x: 1, y: 799), CGPoint(x: 1_199, y: 799)] {
            let frame = PanelPositioner.frame(panelSize: CGSize(width: 560, height: 440), pointer: point, screens: [screen])
            XCTAssertTrue(screen.visibleFrame.contains(frame), "Frame \(frame) should fit for \(point)")
        }
    }

    func testPanelPositionUsesPointerScreen() {
        let primary = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1_200, height: 800), visibleFrame: CGRect(x: 0, y: 24, width: 1_200, height: 746))
        let external = ScreenGeometry(frame: CGRect(x: -1_600, y: 100, width: 1_600, height: 900), visibleFrame: CGRect(x: -1_600, y: 124, width: 1_600, height: 840))
        let frame = PanelPositioner.frame(panelSize: CGSize(width: 560, height: 440), pointer: CGPoint(x: -800, y: 500), screens: [primary, external])
        XCTAssertTrue(external.visibleFrame.contains(frame))
    }

    func testScreenCenterPlacementUsesThePointerDisplayVisibleFrame() {
        let screen = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1_200, height: 800), visibleFrame: CGRect(x: 0, y: 24, width: 1_200, height: 746))
        let frame = PanelPositioner.frame(panelSize: CGSize(width: 560, height: 440), pointer: CGPoint(x: 300, y: 500), screens: [screen], anchor: .screenCenter)
        XCTAssertEqual(frame.midX, screen.visibleFrame.midX)
        XCTAssertEqual(frame.midY, screen.visibleFrame.midY)
    }

    private func item(_ text: String, date: TimeInterval, pinned: Bool) -> ClipboardSearchItem {
        ClipboardSearchItem(id: UUID(), kind: .text, displayText: text, searchText: text, sourceApplicationName: nil, lastCopiedAt: Date(timeIntervalSince1970: date), isPinned: pinned)
    }
}
