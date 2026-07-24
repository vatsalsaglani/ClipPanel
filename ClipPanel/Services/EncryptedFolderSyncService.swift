import Foundation

struct EncryptedFolderSyncResult: Sendable, Equatable {
    let importedRecordCount: Int
    let archiveURL: URL
}

/// An explicit, user-driven sync bridge for a folder already managed by the user (for example
/// iCloud Drive, Dropbox, or a removable disk). ClipPanel never discovers folders, keeps a cloud
/// account, or transmits clipboard data itself; the folder receives only an encrypted archive.
@MainActor
enum EncryptedFolderSyncService {
    static let archiveFilename = "ClipPanel.sync.cliparchive"

    static func sync(store: ClipboardStore, folderURL: URL, password: String) throws -> EncryptedFolderSyncResult {
        let archiveURL = folderURL.appendingPathComponent(archiveFilename, isDirectory: false)
        var importedRecordCount = 0
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            importedRecordCount = try ClipArchiveService.importData(Data(contentsOf: archiveURL), into: store, password: password)
        }
        let encryptedArchive = try ClipArchiveService.exportData(from: store, password: password)
        try encryptedArchive.write(to: archiveURL, options: .atomic)
        return EncryptedFolderSyncResult(importedRecordCount: importedRecordCount, archiveURL: archiveURL)
    }
}
