import Foundation
import Observation

enum PanelIntent {
    case pasteOriginal
    case pastePlainText
    case copyOnly
    case deleteSelection
    case togglePin
    case openSettings
    case dismiss
}

@MainActor
@Observable
final class ClipboardPanelState {
    var query = "" {
        didSet {
            setResults(SearchEngine.search(query, in: sourceItems))
            onQueryChanged?(query)
        }
    }
    private var sourceItems: [ClipboardSearchItem] = []
    private(set) var results: [ClipboardSearchItem] = []
    private(set) var selectedID: UUID?
    var statusMessage: String?
    var focusGeneration = 0
    var onQueryChanged: ((String) -> Void)?
    var onIntent: ((PanelIntent) -> Void)?

    var selectedItem: ClipboardSearchItem? { results.first(where: { $0.id == selectedID }) }

    func begin(items: [ClipboardSearchItem], resetQuery: Bool = true) {
        selectedID = nil
        sourceItems = items
        if resetQuery { query = "" }
        else { setResults(SearchEngine.search(query, in: sourceItems)) }
        focusGeneration += 1
    }

    /// Kept as a focused test helper for callers that already provide their final ordering.
    func begin(results: [ClipboardSearchItem], resetQuery: Bool = true) {
        selectedID = nil
        sourceItems = results
        if resetQuery { query = "" }
        setResults(results)
        focusGeneration += 1
    }

    func setSourceItems(_ items: [ClipboardSearchItem]) {
        sourceItems = items
        setResults(SearchEngine.search(query, in: sourceItems))
    }

    func setResults(_ newResults: [ClipboardSearchItem]) {
        let retained = newResults.contains(where: { $0.id == selectedID })
        results = newResults
        selectedID = retained ? selectedID : newResults.first?.id
    }

    func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        let current = results.firstIndex(where: { $0.id == selectedID }) ?? 0
        selectedID = results[min(max(current + offset, 0), results.count - 1)].id
    }

    func select(_ id: UUID) { selectedID = id }
    func send(_ intent: PanelIntent) { onIntent?(intent) }
}
