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
            guard query != oldValue else { return }
            resultsHaveKeyboardFocus = false
            selectedID = nil
            refreshResults()
            onQueryChanged?(query)
        }
    }
    var typeFilter: ClipboardTypeFilter = .all { didSet { selectedID = nil; refreshResults() } }
    @ObservationIgnored private var searchIndex = SearchEngine.Index(items: [])
    private(set) var results: [ClipboardSearchItem] = []
    private(set) var selectedID: UUID?
    var statusMessage: String?
    var focusGeneration = 0
    var resultsHaveKeyboardFocus = false
    private(set) var isPreviewVisible = false { didSet { onPreviewVisibilityChanged?() } }
    var onPreviewVisibilityChanged: (() -> Void)?
    private(set) var preview: ClipboardQuickPreview?
    @ObservationIgnored private var previewID: UUID?
    var onQueryChanged: ((String) -> Void)?
    var onIntent: ((PanelIntent) -> Void)?
    var onTransformRequested: ((ClipboardTextTransformation) -> Void)?
    var previewProvider: ((UUID) -> ClipboardPayload?)?

    var selectedItem: ClipboardSearchItem? { results.first(where: { $0.id == selectedID }) }
    var canTransformSelection: Bool { selectedItem.map { ClipboardTypeFilter.text.matches($0.kind) } ?? false }

    func begin(items: [ClipboardSearchItem], resetQuery: Bool = true) {
        selectedID = nil
        resultsHaveKeyboardFocus = false
        closePreview()
        searchIndex = SearchEngine.Index(items: items)
        if resetQuery { query = "" }
        refreshResults()
        focusGeneration += 1
    }

    /// Kept as a focused test helper for callers that already provide their final ordering.
    func begin(results: [ClipboardSearchItem], resetQuery: Bool = true) {
        begin(items: results, resetQuery: resetQuery)
        setResults(results)
    }

    func setSourceItems(_ items: [ClipboardSearchItem]) {
        searchIndex = SearchEngine.Index(items: items)
        refreshResults()
    }

    private func refreshResults() {
        setResults(searchIndex.search(query, filter: typeFilter))
    }

    func setResults(_ newResults: [ClipboardSearchItem]) {
        let retained = newResults.contains(where: { $0.id == selectedID })
        results = newResults
        selectedID = retained ? selectedID : newResults.first?.id
        updatePreview()
    }

    func moveSelection(by offset: Int) {
        resultsHaveKeyboardFocus = true
        guard !results.isEmpty else { return }
        let current = results.firstIndex(where: { $0.id == selectedID }) ?? 0
        select(results[min(max(current + offset, 0), results.count - 1)].id)
    }

    func select(_ id: UUID) {
        guard results.contains(where: { $0.id == id }) else { return }
        selectedID = id
        updatePreview()
    }

    /// Shortcuts always address the displayed results, including active filters/search ranking.
    @discardableResult
    func pasteResult(number: Int) -> Bool {
        guard (1...9).contains(number), results.indices.contains(number - 1) else { return false }
        select(results[number - 1].id)
        send(.pasteOriginal)
        return true
    }

    func togglePreview() {
        guard selectedItem != nil else { return }
        isPreviewVisible.toggle()
        updatePreview()
    }

    func closePreview() {
        isPreviewVisible = false
        preview = nil
        previewID = nil
    }

    private func updatePreview() {
        guard isPreviewVisible, let item = selectedItem else { preview = nil; previewID = nil; return }
        guard previewID != item.id else { return }
        previewID = item.id
        // Payload access occurs only for the selected item and only on explicit preview.
        preview = ClipboardQuickPreview(item: item, payload: previewProvider?(item.id))
    }

    func send(_ intent: PanelIntent) { onIntent?(intent) }
}
