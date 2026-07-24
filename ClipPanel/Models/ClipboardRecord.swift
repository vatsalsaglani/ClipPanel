import Foundation
import SwiftData

@Model
final class ClipboardRecord {
    var id: UUID
    var createdAt: Date
    var lastCopiedAt: Date
    var lastPastedAt: Date?
    var sourceBundleIdentifier: String?
    var sourceApplicationName: String?
    var kindRawValue: String
    var displayText: String
    var searchText: String
    var contentHash: String
    var byteCount: Int
    var itemCount: Int
    var isPinned: Bool
    @Attribute(.externalStorage) var payloadData: Data

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        lastCopiedAt: Date = .now,
        lastPastedAt: Date? = nil,
        sourceBundleIdentifier: String? = nil,
        sourceApplicationName: String? = nil,
        kind: ClipboardKind,
        displayText: String,
        searchText: String,
        contentHash: String,
        byteCount: Int,
        itemCount: Int,
        isPinned: Bool = false,
        payloadData: Data
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastCopiedAt = lastCopiedAt
        self.lastPastedAt = lastPastedAt
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceApplicationName = sourceApplicationName
        kindRawValue = kind.rawValue
        self.displayText = displayText
        self.searchText = searchText
        self.contentHash = contentHash
        self.byteCount = byteCount
        self.itemCount = itemCount
        self.isPinned = isPinned
        self.payloadData = payloadData
    }

    var kind: ClipboardKind { ClipboardKind(rawValue: kindRawValue) ?? .mixed }
}
