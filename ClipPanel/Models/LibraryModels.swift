import Foundation
import SwiftData

/// Optional, user-authored metadata. It is deliberately separate from the captured record so
/// capture remains append-only and existing clipboard history migrates without rewriting payloads.
@Model
final class ClipMetadata {
    var id: UUID
    var recordID: UUID
    var customTitle: String
    var note: String
    var isSavedSnippet: Bool
    var isFavorite: Bool
    var tagIDs: [UUID]
    var collectionIDs: [UUID]
    var encryptedPayloadData: Data?
    var encryptionNonce: Data?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        recordID: UUID,
        customTitle: String = "",
        note: String = "",
        isSavedSnippet: Bool = false,
        isFavorite: Bool = false,
        tagIDs: [UUID] = [],
        collectionIDs: [UUID] = [],
        encryptedPayloadData: Data? = nil,
        encryptionNonce: Data? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.recordID = recordID
        self.customTitle = customTitle
        self.note = note
        self.isSavedSnippet = isSavedSnippet
        self.isFavorite = isFavorite
        self.tagIDs = tagIDs
        self.collectionIDs = collectionIDs
        self.encryptedPayloadData = encryptedPayloadData
        self.encryptionNonce = encryptionNonce
        self.updatedAt = updatedAt
    }
}

@Model
final class ClipTag {
    var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class ClipCollection {
    var id: UUID
    var name: String
    var isEncrypted: Bool
    var createdAt: Date

    init(id: UUID = UUID(), name: String, isEncrypted: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.isEncrypted = isEncrypted
        self.createdAt = createdAt
    }
}

@Model
final class ClipSmartFilter {
    var id: UUID
    var name: String
    var query: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, query: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.query = query
        self.createdAt = createdAt
    }
}

struct ClipMetadataSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let recordID: UUID
    let customTitle: String
    let note: String
    let isSavedSnippet: Bool
    let isFavorite: Bool
    let tagIDs: [UUID]
    let collectionIDs: [UUID]
    let isEncrypted: Bool

    init(metadata: ClipMetadata) {
        id = metadata.id
        recordID = metadata.recordID
        customTitle = metadata.customTitle
        note = metadata.note
        isSavedSnippet = metadata.isSavedSnippet
        isFavorite = metadata.isFavorite
        tagIDs = metadata.tagIDs
        collectionIDs = metadata.collectionIDs
        isEncrypted = metadata.encryptedPayloadData != nil
    }
}

struct ClipLibraryItem: Identifiable, Equatable, Sendable {
    let record: ClipboardSearchItem
    let metadata: ClipMetadataSnapshot?
    let tagNames: [String]
    let collectionNames: [String]

    var id: UUID { record.id }
    var title: String { metadata?.customTitle.nonEmpty ?? record.displayText }
    var note: String { metadata?.note ?? "" }
    var isFavorite: Bool { metadata?.isFavorite ?? false }
    var isSavedSnippet: Bool { metadata?.isSavedSnippet ?? false }
    var isEncrypted: Bool { metadata?.isEncrypted ?? false }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
