import AppKit
import Foundation
import SwiftData

@MainActor
final class ClipboardStore {
    private let modelContext: ModelContext
    private var vault: EncryptedPayloadVault?
    private let vaultProvider: () throws -> EncryptedPayloadVault

    init(modelContext: ModelContext, vault: EncryptedPayloadVault? = nil,
         vaultProvider: @escaping () throws -> EncryptedPayloadVault = { try EncryptedPayloadVault() }) {
        self.modelContext = modelContext
        self.vault = vault
        self.vaultProvider = vaultProvider
    }

    private func encryptionVault() throws -> EncryptedPayloadVault {
        if let vault { return vault }
        // Ordinary history and search do not need encryption-key access. Wait
        // until an explicit encrypted read/write before asking the Keychain.
        let loaded = try vaultProvider()
        vault = loaded
        return loaded
    }

    @discardableResult
    func upsert(_ candidate: ClipboardCaptureCandidate, historyLimit: Int, maximumAgeDays: Int = 0, now: Date = .now) throws -> ClipboardRecord {
        let hash = candidate.contentHash
        let descriptor = FetchDescriptor<ClipboardRecord>(predicate: #Predicate { $0.contentHash == hash })
        let existing = try modelContext.fetch(descriptor).first(where: { $0.payloadData == candidate.encodedPayload })
        if let existing {
            existing.lastCopiedAt = now
            existing.sourceBundleIdentifier = candidate.source?.bundleIdentifier ?? existing.sourceBundleIdentifier
            existing.sourceApplicationName = candidate.source?.name ?? existing.sourceApplicationName
            try modelContext.save()
            try enforceRetention(limit: historyLimit, maximumAgeDays: maximumAgeDays, now: now)
            return existing
        }

        let record = ClipboardRecord(
            createdAt: now,
            lastCopiedAt: now,
            sourceBundleIdentifier: candidate.source?.bundleIdentifier,
            sourceApplicationName: candidate.source?.name,
            kind: candidate.preview.kind,
            displayText: candidate.preview.displayText,
            searchText: candidate.preview.searchText,
            contentHash: candidate.contentHash,
            byteCount: candidate.payload.byteCount,
            itemCount: candidate.payload.items.count,
            payloadData: candidate.encodedPayload
        )
        modelContext.insert(record)
        try modelContext.save()
        try enforceRetention(limit: historyLimit, maximumAgeDays: maximumAgeDays, now: now)
        return record
    }

    func records() throws -> [ClipboardRecord] {
        let descriptor = FetchDescriptor<ClipboardRecord>(sortBy: [SortDescriptor(\.lastCopiedAt, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }

    func searchItems() throws -> [ClipboardSearchItem] {
        try libraryItems(includePayloadDetails: false).map(\.record)
    }

    func libraryItems(includePayloadDetails: Bool = true) throws -> [ClipLibraryItem] {
        let metadataByRecordID = Dictionary(uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<ClipMetadata>()).map { ($0.recordID, $0) })
        let tagsByID = Dictionary(uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<ClipTag>()).map { ($0.id, $0.name) })
        let collectionsByID = Dictionary(uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<ClipCollection>()).map { ($0.id, $0.name) })
        return try records().map { record in
            let payload = includePayloadDetails && (record.kind == .image || record.kind == .files) ? try? payload(for: record) : nil
            let fileURLs = payload.map(PreviewBuilder.fileURLs(from:)) ?? []
            let metadata = metadataByRecordID[record.id]
            let snapshot = metadata.map(ClipMetadataSnapshot.init)
            let tagNames = metadata?.tagIDs.compactMap { tagsByID[$0] } ?? []
            let collectionNames = metadata?.collectionIDs.compactMap { collectionsByID[$0] } ?? []
            let displayText = metadata?.customTitle.isEmpty == false ? metadata!.customTitle : record.displayText
            let item = ClipboardSearchItem(
                id: record.id,
                kind: record.kind,
                displayText: displayText,
                searchText: [record.searchText, metadata?.note ?? "", metadata?.customTitle ?? ""].joined(separator: " "),
                sourceApplicationName: record.sourceApplicationName,
                lastCopiedAt: record.lastCopiedAt,
                isPinned: record.isPinned,
                thumbnailData: (payload?.data(forTypeIdentifier: NSPasteboard.PasteboardType.png.rawValue)
                    ?? payload?.data(forTypeIdentifier: NSPasteboard.PasteboardType.tiff.rawValue)),
                detailText: record.kind == .image ? payload.flatMap(PreviewBuilder.imageDetail(from:)) : payload.flatMap(PreviewBuilder.fileDetail(from:)),
                fileURL: fileURLs.first,
                tagNames: tagNames,
                collectionNames: collectionNames,
                isSavedSnippet: metadata?.isSavedSnippet ?? false,
                isFavorite: metadata?.isFavorite ?? false
            )
            return ClipLibraryItem(record: item, metadata: snapshot, tagNames: tagNames, collectionNames: collectionNames)
        }
    }

    func metadata(for recordID: UUID) throws -> ClipMetadata? {
        let identifier = recordID
        let descriptor = FetchDescriptor<ClipMetadata>(predicate: #Predicate { $0.recordID == identifier })
        return try modelContext.fetch(descriptor).first
    }

    func payload(for record: ClipboardRecord) throws -> ClipboardPayload {
        let data = try encodedPayload(for: record)
        do {
            return try JSONDecoder().decode(ClipboardPayload.self, from: data)
        } catch {
            throw ClipboardStoreError.invalidPayload
        }
    }

    func text(for record: ClipboardRecord) throws -> String? {
        PreviewBuilder.text(from: try payload(for: record))
    }

    func encodedPayload(for record: ClipboardRecord) throws -> Data {
        guard let metadata = try metadata(for: record.id), let encrypted = metadata.encryptedPayloadData else {
            return record.payloadData
        }
        let vault = try encryptionVault()
        return try vault.decrypt(encrypted)
    }

    @discardableResult
    func updateMetadata(
        recordID: UUID,
        title: String? = nil,
        note: String? = nil,
        isSavedSnippet: Bool? = nil,
        isFavorite: Bool? = nil,
        tagIDs: [UUID]? = nil,
        collectionIDs: [UUID]? = nil
    ) throws -> ClipMetadata {
        let metadata = try metadata(for: recordID) ?? ClipMetadata(recordID: recordID)
        if metadata.modelContext == nil { modelContext.insert(metadata) }
        if let title { metadata.customTitle = title.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let note { metadata.note = note.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let isSavedSnippet { metadata.isSavedSnippet = isSavedSnippet }
        if let isFavorite { metadata.isFavorite = isFavorite }
        if let tagIDs { metadata.tagIDs = Array(Set(tagIDs)) }
        if let collectionIDs { metadata.collectionIDs = Array(Set(collectionIDs)) }
        metadata.updatedAt = .now
        if let record = try record(id: recordID) {
            try applyEncryptionState(record: record, metadata: metadata)
        }
        try modelContext.save()
        return metadata
    }

    func tags() throws -> [ClipTag] {
        try modelContext.fetch(FetchDescriptor<ClipTag>(sortBy: [SortDescriptor(\.name)]))
    }

    @discardableResult
    func createTag(named name: String) throws -> ClipTag {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw ClipboardStoreError.emptyName }
        if let existing = try tags().first(where: { $0.name.localizedCaseInsensitiveCompare(normalized) == .orderedSame }) { return existing }
        let tag = ClipTag(name: normalized)
        modelContext.insert(tag)
        try modelContext.save()
        return tag
    }

    func collections() throws -> [ClipCollection] {
        try modelContext.fetch(FetchDescriptor<ClipCollection>(sortBy: [SortDescriptor(\.name)]))
    }

    @discardableResult
    func createCollection(named name: String, isEncrypted: Bool = false) throws -> ClipCollection {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw ClipboardStoreError.emptyName }
        if let existing = try collections().first(where: { $0.name.localizedCaseInsensitiveCompare(normalized) == .orderedSame }) { return existing }
        let collection = ClipCollection(name: normalized, isEncrypted: isEncrypted)
        modelContext.insert(collection)
        try modelContext.save()
        return collection
    }

    func smartFilters() throws -> [ClipSmartFilter] {
        try modelContext.fetch(FetchDescriptor<ClipSmartFilter>(sortBy: [SortDescriptor(\.name)]))
    }

    @discardableResult
    func createSmartFilter(name: String, query: String) throws -> ClipSmartFilter {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty, !normalizedQuery.isEmpty else { throw ClipboardStoreError.emptyName }
        let filter = ClipSmartFilter(name: normalizedName, query: normalizedQuery)
        modelContext.insert(filter)
        try modelContext.save()
        return filter
    }

    func deleteTag(_ tag: ClipTag) throws {
        let tagID = tag.id
        for metadata in try modelContext.fetch(FetchDescriptor<ClipMetadata>()) where metadata.tagIDs.contains(tagID) {
            metadata.tagIDs.removeAll { $0 == tagID }
        }
        modelContext.delete(tag)
        try modelContext.save()
    }

    func deleteCollection(_ collection: ClipCollection) throws {
        let collectionID = collection.id
        for metadata in try modelContext.fetch(FetchDescriptor<ClipMetadata>()) where metadata.collectionIDs.contains(collectionID) {
            metadata.collectionIDs.removeAll { $0 == collectionID }
            if let record = try record(id: metadata.recordID) {
                try applyEncryptionState(record: record, metadata: metadata)
            }
        }
        modelContext.delete(collection)
        try modelContext.save()
    }

    func record(id: UUID) throws -> ClipboardRecord? {
        let descriptor = FetchDescriptor<ClipboardRecord>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    func delete(_ record: ClipboardRecord) throws {
        if let metadata = try metadata(for: record.id) { modelContext.delete(metadata) }
        modelContext.delete(record)
        try modelContext.save()
    }

    func clearUnpinned() throws {
        for record in try records().filter({ !$0.isPinned }) {
            if let metadata = try metadata(for: record.id) { modelContext.delete(metadata) }
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    func clearAll() throws {
        try modelContext.fetch(FetchDescriptor<ClipMetadata>()).forEach(modelContext.delete)
        try records().forEach(modelContext.delete)
        try modelContext.save()
    }

    /// Automatic cleanup applies only to disposable capture history. Library ownership and
    /// encryption are inspected as metadata, without decrypting or touching payload bytes.
    @discardableResult
    func enforceRetention(limit: Int, maximumAgeDays: Int = 0, now: Date = .now) throws -> Int {
        let allRecords = try records()
        guard maximumAgeDays > 0 || allRecords.count > max(limit, 0) else { return 0 }
        let metadataByRecordID = Dictionary(uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<ClipMetadata>()).map { ($0.recordID, $0) })
        let disposable = allRecords.filter { record in
            guard !record.isPinned else { return false }
            guard let metadata = metadataByRecordID[record.id] else { return true }
            return !metadata.isSavedSnippet && !metadata.isFavorite && metadata.collectionIDs.isEmpty && metadata.encryptedPayloadData == nil
        }
        let cutoff = maximumAgeDays > 0 ? now.addingTimeInterval(-TimeInterval(maximumAgeDays) * 86_400) : nil
        var removed = 0
        for (index, record) in disposable.enumerated() {
            let expired = cutoff.map { record.lastCopiedAt < $0 } ?? false
            guard index >= max(limit, 0) || expired else { continue }
            if let metadata = metadataByRecordID[record.id] { modelContext.delete(metadata) }
            modelContext.delete(record)
            removed += 1
        }
        if removed > 0 { try modelContext.save() }
        return removed
    }

    func setPinned(_ record: ClipboardRecord, isPinned: Bool) throws {
        record.isPinned = isPinned
        try modelContext.save()
    }

    func markPasted(_ record: ClipboardRecord, at date: Date = .now) throws {
        record.lastPastedAt = date
        try modelContext.save()
    }

    @discardableResult
    func createTransformedRecord(from record: ClipboardRecord, transformation: ClipboardTextTransformation) throws -> ClipboardRecord? {
        guard let payload = try? payload(for: record),
              let transformed = ClipboardTransformationService.transform(payload, using: transformation),
              let encoded = try? JSONEncoder().encode(transformed) else { return nil }
        let preview = PreviewBuilder.build(payload: transformed)
        let candidate = ClipboardCaptureCandidate(
            payload: transformed,
            encodedPayload: encoded,
            preview: preview,
            contentHash: ClipboardHasher.hash(payload: transformed),
            source: nil
        )
        return try upsert(candidate, historyLimit: Int.max)
    }

    @discardableResult
    func createTransformedRecord(from record: ClipboardRecord, command: CustomTextCommand) throws -> ClipboardRecord? {
        guard let payload = try? payload(for: record),
              let transformed = ClipboardTransformationService.transform(payload, using: command),
              let encoded = try? JSONEncoder().encode(transformed) else { return nil }
        let preview = PreviewBuilder.build(payload: transformed)
        let candidate = ClipboardCaptureCandidate(
            payload: transformed,
            encodedPayload: encoded,
            preview: preview,
            contentHash: ClipboardHasher.hash(payload: transformed),
            source: nil
        )
        return try upsert(candidate, historyLimit: Int.max)
    }

    @discardableResult
    func createEditedTextRecord(from record: ClipboardRecord, text: String) throws -> ClipboardRecord? {
        guard !text.isEmpty else { return nil }
        let payload = ClipboardPayload(items: [ClipboardPayloadItem(representations: [
            ClipboardRepresentation(typeIdentifier: NSPasteboard.PasteboardType.string.rawValue, data: Data(text.utf8))
        ])])
        guard let encoded = try? JSONEncoder().encode(payload) else { return nil }
        let preview = PreviewBuilder.build(payload: payload)
        let candidate = ClipboardCaptureCandidate(
            payload: payload,
            encodedPayload: encoded,
            preview: preview,
            contentHash: ClipboardHasher.hash(payload: payload),
            source: SourceApplication(bundleIdentifier: record.sourceBundleIdentifier, name: record.sourceApplicationName)
        )
        return try upsert(candidate, historyLimit: Int.max)
    }

    func archiveSnapshot() throws -> ClipArchive {
        let allRecords = try records()
        let metadataByRecordID = Dictionary(uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<ClipMetadata>()).map { ($0.recordID, $0) })
        let archiveRecords = try allRecords.map { record in
            let metadata = metadataByRecordID[record.id].map {
                ClipArchiveMetadata(
                    customTitle: $0.customTitle,
                    note: $0.note,
                    isSavedSnippet: $0.isSavedSnippet,
                    isFavorite: $0.isFavorite,
                    tagIDs: $0.tagIDs,
                    collectionIDs: $0.collectionIDs
                )
            }
            return ClipArchiveRecord(
                originalID: record.id,
                createdAt: record.createdAt,
                lastCopiedAt: record.lastCopiedAt,
                lastPastedAt: record.lastPastedAt,
                sourceBundleIdentifier: record.sourceBundleIdentifier,
                sourceApplicationName: record.sourceApplicationName,
                isPinned: record.isPinned,
                payloadData: try encodedPayload(for: record),
                metadata: metadata
            )
        }
        return ClipArchive(
            version: ClipArchive.currentVersion,
            exportedAt: .now,
            records: archiveRecords,
            tags: try tags().map { ClipArchiveTag(originalID: $0.id, name: $0.name) },
            collections: try collections().map { ClipArchiveCollection(originalID: $0.id, name: $0.name, isEncrypted: $0.isEncrypted) },
            smartFilters: try smartFilters().map { ClipArchiveSmartFilter(name: $0.name, query: $0.query) }
        )
    }

    @discardableResult
    func importArchive(_ archive: ClipArchive) throws -> Int {
        var tagIDs: [UUID: UUID] = [:]
        for tag in archive.tags {
            tagIDs[tag.originalID] = try createTag(named: tag.name).id
        }
        var collectionIDs: [UUID: UUID] = [:]
        for collection in archive.collections {
            collectionIDs[collection.originalID] = try createCollection(named: collection.name, isEncrypted: collection.isEncrypted).id
        }
        let existingFilters = try smartFilters()
        for filter in archive.smartFilters where !existingFilters.contains(where: { $0.name == filter.name && $0.query == filter.query }) {
            _ = try createSmartFilter(name: filter.name, query: filter.query)
        }

        var importedCount = 0
        for archivedRecord in archive.records {
            guard let payload = try? JSONDecoder().decode(ClipboardPayload.self, from: archivedRecord.payloadData) else {
                throw ClipboardStoreError.invalidPayload
            }
            let preview = PreviewBuilder.build(payload: payload)
            let candidate = ClipboardCaptureCandidate(
                payload: payload,
                encodedPayload: archivedRecord.payloadData,
                preview: preview,
                contentHash: ClipboardHasher.hash(payload: payload),
                source: SourceApplication(bundleIdentifier: archivedRecord.sourceBundleIdentifier, name: archivedRecord.sourceApplicationName)
            )
            let record = try upsert(candidate, historyLimit: Int.max, now: archivedRecord.lastCopiedAt)
            record.createdAt = min(record.createdAt, archivedRecord.createdAt)
            record.lastCopiedAt = max(record.lastCopiedAt, archivedRecord.lastCopiedAt)
            record.lastPastedAt = archivedRecord.lastPastedAt ?? record.lastPastedAt
            record.isPinned = record.isPinned || archivedRecord.isPinned
            if let metadata = archivedRecord.metadata {
                _ = try updateMetadata(
                    recordID: record.id,
                    title: metadata.customTitle,
                    note: metadata.note,
                    isSavedSnippet: metadata.isSavedSnippet,
                    isFavorite: metadata.isFavorite,
                    tagIDs: metadata.tagIDs.compactMap { tagIDs[$0] },
                    collectionIDs: metadata.collectionIDs.compactMap { collectionIDs[$0] }
                )
            }
            importedCount += 1
        }
        try modelContext.save()
        return importedCount
    }

    private func applyEncryptionState(record: ClipboardRecord, metadata: ClipMetadata) throws {
        let selectedCollections = try collections().filter { metadata.collectionIDs.contains($0.id) }
        let shouldEncrypt = selectedCollections.contains(where: \.isEncrypted)
        if shouldEncrypt, metadata.encryptedPayloadData == nil {
            let vault = try encryptionVault()
            let encryptedPayload = try vault.encrypt(record.payloadData)
            metadata.encryptedPayloadData = encryptedPayload
            metadata.encryptionNonce = nil
            record.payloadData = Data()
        } else if !shouldEncrypt, let encryptedPayload = metadata.encryptedPayloadData {
            let vault = try encryptionVault()
            record.payloadData = try vault.decrypt(encryptedPayload)
            metadata.encryptedPayloadData = nil
            metadata.encryptionNonce = nil
        }
    }
}

enum ClipboardStoreError: LocalizedError {
    case emptyName
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .emptyName: "Enter a name before continuing."
        case .invalidPayload: "The saved clipboard item could not be decoded."
        }
    }
}
