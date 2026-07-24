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
        let parsed = SearchQuery(query)
        guard parsed.hasCriteria else {
            return items.sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned }
                return $0.lastCopiedAt > $1.lastCopiedAt
            }
        }
        let matches: [(ClipboardSearchItem, Int)] = items.compactMap { item in
            guard parsed.matchesFilters(item) else { return nil }
            let haystack = normalize([item.displayText, item.searchText, item.sourceApplicationName, item.kind.displayName, item.tagNames.joined(separator: " "), item.collectionNames.joined(separator: " ")].compactMap { $0 }.joined(separator: " "))
            if let expression = parsed.regularExpression, expression.firstMatch(in: haystack, range: NSRange(haystack.startIndex..., in: haystack)) == nil { return nil }
            let scores = parsed.tokens.compactMap { score(token: $0, in: item) }
            guard scores.count == parsed.tokens.count else { return nil }
            return (item, scores.reduce(0, +))
        }
        return matches.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            if $0.0.isPinned != $1.0.isPinned { return $0.0.isPinned }
            return $0.0.lastCopiedAt > $1.0.lastCopiedAt
        }
        .map(\.0)
    }

    static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func displayMatchRanges(query: String, in value: String) -> [Range<String.Index>] {
        let tokens = normalize(query).split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return [] }
        return tokens.compactMap { token in
            value.range(of: token, options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
    }

    /// Prefer the result users can immediately see in the panel. Full clipboard text remains
    /// searchable, but a title match should not lose to a newer record whose match is buried in
    /// long body text or metadata.
    private static func score(token: String, in item: ClipboardSearchItem) -> Int? {
        let titleScore = score(token: token, in: normalize(item.displayText))
        let contentScore = score(token: token, in: normalize(item.searchText))
        let sourceScore = score(token: token, in: normalize(item.sourceApplicationName ?? ""))
        let tagScore = score(token: token, in: normalize(item.tagNames.joined(separator: " ")))
        let collectionScore = score(token: token, in: normalize(item.collectionNames.joined(separator: " ")))
        return [
            titleScore.map { $0 * 5 },
            contentScore.map { $0 * 2 },
            sourceScore,
            tagScore,
            collectionScore
        ].compactMap { $0 }.max()
    }

    private static func score(token: String, in value: String) -> Int? {
        if value == token { return 1_000 }
        if value.hasPrefix(token) { return 800 }
        if value.range(of: "\\b\(NSRegularExpression.escapedPattern(for: token))", options: .regularExpression) != nil { return 650 }
        if value.contains(token) { return 450 }
        return isSubsequence(token, of: value) ? 100 : nil
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var start = haystack.startIndex
        for expected in needle {
            guard let found = haystack[start...].firstIndex(of: expected) else { return false }
            start = haystack.index(after: found)
        }
        return true
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
