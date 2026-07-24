import CryptoKit
import Foundation

enum ClipArchiveError: LocalizedError, Equatable {
    case passwordRequired
    case invalidArchive
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .passwordRequired: "Enter the archive password to continue."
        case .invalidArchive: "This file is not a valid ClipPanel archive."
        case .unsupportedVersion: "This ClipPanel archive uses a newer format."
        }
    }
}

struct ClipArchive: Codable, Sendable {
    static let currentVersion = 1
    let version: Int
    let exportedAt: Date
    let records: [ClipArchiveRecord]
    let tags: [ClipArchiveTag]
    let collections: [ClipArchiveCollection]
    let smartFilters: [ClipArchiveSmartFilter]
}

struct ClipArchiveRecord: Codable, Sendable {
    let originalID: UUID
    let createdAt: Date
    let lastCopiedAt: Date
    let lastPastedAt: Date?
    let sourceBundleIdentifier: String?
    let sourceApplicationName: String?
    let isPinned: Bool
    let payloadData: Data
    let metadata: ClipArchiveMetadata?
}

struct ClipArchiveMetadata: Codable, Sendable {
    let customTitle: String
    let note: String
    let isSavedSnippet: Bool
    let isFavorite: Bool
    let tagIDs: [UUID]
    let collectionIDs: [UUID]
}

struct ClipArchiveTag: Codable, Sendable {
    let originalID: UUID
    let name: String
}

struct ClipArchiveCollection: Codable, Sendable {
    let originalID: UUID
    let name: String
    let isEncrypted: Bool
}

struct ClipArchiveSmartFilter: Codable, Sendable {
    let name: String
    let query: String
}

private struct EncryptedClipArchive: Codable {
    let format: String
    let version: Int
    let salt: Data
    let ciphertext: Data
}

@MainActor
enum ClipArchiveService {
    static func exportData(from store: ClipboardStore, password: String? = nil) throws -> Data {
        let archive = try store.archiveSnapshot()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let rawArchive = try encoder.encode(archive)
        guard let password, !password.isEmpty else { return rawArchive }

        let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let key = deriveKey(password: password, salt: salt)
        let sealedBox = try AES.GCM.seal(rawArchive, using: key)
        guard let ciphertext = sealedBox.combined else { throw ClipArchiveError.invalidArchive }
        return try encoder.encode(EncryptedClipArchive(format: "ClipPanel Encrypted Archive", version: ClipArchive.currentVersion, salt: salt, ciphertext: ciphertext))
    }

    static func importData(_ data: Data, into store: ClipboardStore, password: String? = nil) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rawArchive: Data
        if let envelope = try? decoder.decode(EncryptedClipArchive.self, from: data) {
            guard envelope.format == "ClipPanel Encrypted Archive" else { throw ClipArchiveError.invalidArchive }
            guard let password, !password.isEmpty else { throw ClipArchiveError.passwordRequired }
            guard envelope.version <= ClipArchive.currentVersion,
                  let sealedBox = try? AES.GCM.SealedBox(combined: envelope.ciphertext) else { throw ClipArchiveError.invalidArchive }
            do {
                rawArchive = try AES.GCM.open(sealedBox, using: deriveKey(password: password, salt: envelope.salt))
            } catch {
                throw ClipArchiveError.invalidArchive
            }
        } else {
            rawArchive = data
        }
        let archive: ClipArchive
        do {
            archive = try decoder.decode(ClipArchive.self, from: rawArchive)
        } catch {
            throw ClipArchiveError.invalidArchive
        }
        guard archive.version <= ClipArchive.currentVersion else { throw ClipArchiveError.unsupportedVersion }
        return try store.importArchive(archive)
    }

    static func requiresPassword(for data: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(EncryptedClipArchive.self, from: data)) != nil
    }

    private static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        let passwordKey = SymmetricKey(data: Data(password.utf8))
        var block = salt
        block.append(contentsOf: [0, 0, 0, 1])
        var current = Data(HMAC<SHA256>.authenticationCode(for: block, using: passwordKey))
        var output = current
        // PBKDF2-HMAC-SHA256, one 256-bit output block. The count is intentionally large enough
        // to make offline guessing of an exported archive materially more expensive.
        for _ in 1..<120_000 {
            current = Data(HMAC<SHA256>.authenticationCode(for: current, using: passwordKey))
            for index in output.indices { output[index] ^= current[index] }
        }
        return SymmetricKey(data: output)
    }
}
