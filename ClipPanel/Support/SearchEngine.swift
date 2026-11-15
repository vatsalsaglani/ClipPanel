import Foundation

struct ClipboardSearchItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: ClipboardKind
    let displayText: String
    let searchText: String
    let sourceApplicationName: String?
    let lastCopiedAt: Date
    let isPinned: Bool
    let thumbnailData: Data?
    let detailText: String?
    let fileURL: URL?
    let tagNames: [String]
    let collectionNames: [String]
    let isSavedSnippet: Bool
    let isFavorite: Bool

    init(id: UUID, kind: ClipboardKind, displayText: String, searchText: String, sourceApplicationName: String?, lastCopiedAt: Date, isPinned: Bool, thumbnailData: Data? = nil, detailText: String? = nil, fileURL: URL? = nil, tagNames: [String] = [], collectionNames: [String] = [], isSavedSnippet: Bool = false, isFavorite: Bool = false) {
        self.id = id
        self.kind = kind
        self.displayText = displayText
        self.searchText = searchText
        self.sourceApplicationName = sourceApplicationName
        self.lastCopiedAt = lastCopiedAt
        self.isPinned = isPinned
        self.thumbnailData = thumbnailData
        self.detailText = detailText
        self.fileURL = fileURL
        self.tagNames = tagNames
        self.collectionNames = collectionNames
        self.isSavedSnippet = isSavedSnippet
        self.isFavorite = isFavorite
    }
}

enum SearchEngine {
    static func search(_ query: String, in items: [ClipboardSearchItem]) -> [ClipboardSearchItem] {
        guard SearchQuery(query).hasCriteria else { return items.sorted(by: precedes) }
        return Index(items: items).search(query)
    }

    /// Builds normalized fields once per history snapshot, never once per keystroke.
    struct Index {
        private let entries: [(item: ClipboardSearchItem, fields: NormalizedSearchFields)]

        init(items: [ClipboardSearchItem]) {
            entries = items.sorted(by: SearchEngine.precedes).map { ($0, NormalizedSearchFields($0)) }
        }

        func search(_ query: String, filter: ClipboardTypeFilter = .all) -> [ClipboardSearchItem] {
            let parsed = SearchQuery(query)
            guard parsed.hasCriteria else { return entries.compactMap { filter.matches($0.item.kind) ? $0.item : nil } }
            let searchTerms = parsed.tokens.map(SearchTerm.init)
            let matches: [(ClipboardSearchItem, Int)] = entries.compactMap { entry in
                let item = entry.item
                guard filter.matches(item.kind) else { return nil }
                guard parsed.matchesFilters(item) else { return nil }
                if let expression = parsed.regularExpression {
                    let haystack = entry.fields.regexText
                    if expression.firstMatch(in: haystack, range: NSRange(haystack.startIndex..., in: haystack)) == nil { return nil }
                }
                guard !searchTerms.isEmpty else { return (item, 0) }

                let fields = entry.fields
                var totalScore = 0
                for term in searchTerms {
                    guard let score = score(term: term, in: fields) else { return nil }
                    totalScore += score
                }
                return (item, totalScore)
            }
            return matches.sorted {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                return SearchEngine.precedes($0.0, $1.0)
            }
            .map(\.0)
        }
    }

    private static func precedes(_ lhs: ClipboardSearchItem, _ rhs: ClipboardSearchItem) -> Bool {
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
        if lhs.lastCopiedAt != rhs.lastCopiedAt { return lhs.lastCopiedAt > rhs.lastCopiedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func displayMatchRanges(query: String, in value: String) -> [Range<String.Index>] {
        let tokens = SearchQuery(query).tokens
        guard !tokens.isEmpty else { return [] }
        // Keep original character boundaries while matching folded text (including expanded
        // ligatures and diacritics). Filter syntax is deliberately never highlighted.
        var folded: [Character] = []
        var original: [Range<String.Index>] = []
        for index in value.indices {
            let range = index..<value.index(after: index)
            for character in String(value[range]).folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current) {
                folded.append(character)
                original.append(range)
            }
        }
        var matched = Set<Int>()
        for token in tokens {
            let needle = Array(token)
            guard !needle.isEmpty, needle.count <= folded.count else { continue }
            var contiguous = false
            for start in 0...(folded.count - needle.count) {
                if folded[start..<(start + needle.count)].elementsEqual(needle) {
                    matched.formUnion(start..<(start + needle.count))
                    contiguous = true
                }
            }
            if !contiguous {
                var positions: [Int] = []
                var next = 0
                for character in needle {
                    guard let found = folded[next...].firstIndex(of: character) else { positions = []; break }
                    positions.append(found)
                    next = found + 1
                }
                matched.formUnion(positions)
            }
        }
        let ranges = matched.sorted().map { original[$0] }
        return ranges.reduce(into: []) { result, range in
            if let last = result.last, last.upperBound >= range.lowerBound {
                result[result.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else { result.append(range) }
        }
    }

    /// Prefer the result users can immediately see in the panel. Full clipboard text remains
    /// searchable, but a title match should not lose to a newer record whose match is buried in
    /// long body text or metadata.
    private static func score(term: SearchTerm, in fields: NormalizedSearchFields) -> Int? {
        var bestScore = score(term: term, in: fields.title).map { $0 * 5 }
        if let content = fields.content, let contentScore = score(term: term, in: content).map({ $0 * 2 }),
           contentScore > (bestScore ?? .min) {
            bestScore = contentScore
        }
        if let sourceScore = score(term: term, in: fields.source), sourceScore > (bestScore ?? .min) {
            bestScore = sourceScore
        }
        if let tagScore = score(term: term, in: fields.tags), tagScore > (bestScore ?? .min) {
            bestScore = tagScore
        }
        if let collectionScore = score(term: term, in: fields.collections), collectionScore > (bestScore ?? .min) {
            bestScore = collectionScore
        }
        return bestScore
    }

    private static func score(term: SearchTerm, in value: String) -> Int? {
        if value == term.value { return 1_000 }
        if value.hasPrefix(term.value) { return 800 }
        guard !value.isEmpty else { return nil }
        if term.wordBoundaryExpression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil { return 650 }
        if value.contains(term.value) { return 450 }
        return fuzzyScore(term.value, in: value)
    }

    /// Compact subsequences rank ahead of scattered letters. Never allow fuzzy matches
    /// to outrank a substring, and reject no characters merely because of a typo gap.
    private static func fuzzyScore(_ needle: String, in haystack: String) -> Int? {
        var start = haystack.startIndex
        var gaps = 0
        for expected in needle {
            guard let found = haystack[start...].firstIndex(of: expected) else { return nil }
            gaps += haystack.distance(from: start, to: found)
            start = haystack.index(after: found)
        }
        return max(10, 150 - min(gaps, 140))
    }

    private struct SearchTerm {
        let value: String
        let wordBoundaryExpression: NSRegularExpression

        init(_ value: String) {
            self.value = value
            wordBoundaryExpression = try! NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: value))")
        }
    }

    fileprivate struct NormalizedSearchFields {
        let title: String
        let content: String?
        let source: String
        let tags: String
        let collections: String
        let kindName: String
        var regexText: String { [title, content ?? "", source, kindName, tags, collections].joined(separator: " ") }

        init(_ item: ClipboardSearchItem) {
            title = SearchEngine.normalize(item.displayText)
            if item.searchText == item.displayText {
                content = nil
            } else {
                let normalizedContent = SearchEngine.normalize(item.searchText)
                content = normalizedContent == title ? nil : normalizedContent
            }
            source = item.sourceApplicationName.map(SearchEngine.normalize) ?? ""
            tags = item.tagNames.isEmpty ? "" : SearchEngine.normalize(item.tagNames.joined(separator: " "))
            collections = item.collectionNames.isEmpty ? "" : SearchEngine.normalize(item.collectionNames.joined(separator: " "))
            kindName = item.kind.displayName.lowercased()
        }
    }
}

struct SearchQuery: Sendable {
    let tokens: [String]
    let type: ClipboardKind?
    let application: String?
    let tag: String?
    let collection: String?
    let dateFilter: DateFilter?
    let favoritesOnly: Bool
    let snippetsOnly: Bool
    let regularExpression: NSRegularExpression?

    var hasCriteria: Bool {
        !tokens.isEmpty || type != nil || application != nil || tag != nil || collection != nil || dateFilter != nil || favoritesOnly || snippetsOnly || regularExpression != nil
    }

    init(_ rawValue: String) {
        var remaining: [String] = []
        var parsedType: ClipboardKind?
        var parsedApplication: String?
        var parsedTag: String?
        var parsedCollection: String?
        var parsedDate: DateFilter?
        var parsedFavorites = false
        var parsedSnippets = false
        var regex: NSRegularExpression?

        for token in rawValue.split(separator: " ").map(String.init) {
            let lowercased = token.lowercased()
            if lowercased == "favorite:true" || lowercased == "favorite" { parsedFavorites = true; continue }
            if lowercased == "snippet:true" || lowercased == "snippet" { parsedSnippets = true; continue }
            if lowercased.hasPrefix("type:"), let value = ClipboardKind(rawValue: String(lowercased.dropFirst(5))) { parsedType = value; continue }
            if lowercased.hasPrefix("app:") { parsedApplication = String(token.dropFirst(4)); continue }
            if lowercased.hasPrefix("tag:") { parsedTag = String(token.dropFirst(4)); continue }
            if lowercased.hasPrefix("collection:") { parsedCollection = String(token.dropFirst(11)); continue }
            if lowercased.hasPrefix("date:"), let value = DateFilter(rawValue: String(lowercased.dropFirst(5))) { parsedDate = value; continue }
            if lowercased.hasPrefix("regex:") {
                regex = try? NSRegularExpression(pattern: String(token.dropFirst(6)), options: [.caseInsensitive])
                continue
            }
            remaining.append(token)
        }
        tokens = remaining.map(SearchEngine.normalize)
        type = parsedType
        application = parsedApplication.map(SearchEngine.normalize)
        tag = parsedTag.map(SearchEngine.normalize)
        collection = parsedCollection.map(SearchEngine.normalize)
        dateFilter = parsedDate
        favoritesOnly = parsedFavorites
        snippetsOnly = parsedSnippets
        regularExpression = regex
    }

    func matchesFilters(_ item: ClipboardSearchItem, now: Date = .now) -> Bool {
        if let type, item.kind != type { return false }
        if let application, !SearchEngine.normalize(item.sourceApplicationName ?? "").contains(application) { return false }
        if let tag, !item.tagNames.contains(where: { SearchEngine.normalize($0).contains(tag) }) { return false }
        if let collection, !item.collectionNames.contains(where: { SearchEngine.normalize($0).contains(collection) }) { return false }
        if favoritesOnly, !item.isFavorite { return false }
        if snippetsOnly, !item.isSavedSnippet { return false }
        return dateFilter?.matches(item.lastCopiedAt, now: now) ?? true
    }
}

enum DateFilter: String, Sendable {
    case today
    case yesterday
    case week

    func matches(_ date: Date, now: Date) -> Bool {
        let calendar = Calendar.current
        switch self {
        case .today: return calendar.isDateInToday(date)
        case .yesterday: return calendar.isDateInYesterday(date)
        case .week: return date >= calendar.date(byAdding: .day, value: -7, to: now)!
        }
    }
}

/// Text includes URLs and rich text; the query parser still supports exact `type:` filters.
enum ClipboardTypeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case text = "Text"
    case images = "Images"
    case files = "Files"

    var id: String { rawValue }

    func matches(_ kind: ClipboardKind) -> Bool {
        switch self {
        case .all: true
        case .text: [.text, .richText, .url].contains(kind)
        case .images: kind == .image
        case .files: kind == .files
        }
    }
}
