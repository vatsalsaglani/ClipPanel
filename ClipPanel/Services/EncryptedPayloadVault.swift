import CryptoKit
import Foundation
import Security

enum EncryptedPayloadError: LocalizedError, Equatable {
    case unavailable
    case malformedCiphertext
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .unavailable: "ClipPanel could not access its local encryption key."
        case .malformedCiphertext: "This encrypted clipboard item is malformed."
        case .decryptionFailed: "ClipPanel could not decrypt this clipboard item."
        }
    }
}

/// Small, testable AES-GCM primitive used for local encrypted collections and encrypted archives.
/// The key is deliberately injected here; key custody belongs to `EncryptedPayloadVault`.
struct EncryptedPayloadCipher: Sendable {
    private let key: SymmetricKey

    init(keyData: Data) {
        key = SymmetricKey(data: keyData)
    }

    func seal(_ plaintext: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealedBox.combined else { throw EncryptedPayloadError.malformedCiphertext }
        return combined
    }

    func open(_ ciphertext: Data) throws -> Data {
        guard let sealedBox = try? AES.GCM.SealedBox(combined: ciphertext) else {
            throw EncryptedPayloadError.malformedCiphertext
        }
        do {
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw EncryptedPayloadError.decryptionFailed
        }
    }
}

/// Keeps the per-install encryption key in the Keychain. Clipboard payload bytes never enter logs
/// or UserDefaults, and remain encrypted on disk when attached to an encrypted collection.
@MainActor
final class EncryptedPayloadVault {
    private let cipher: EncryptedPayloadCipher

    init(keyData: Data? = nil, service: String = "com.clippanel.app.encrypted-payloads") throws {
        let material = try keyData ?? KeychainSecret.loadOrCreate(service: service, account: "master-key")
        guard material.count == 32 else { throw EncryptedPayloadError.unavailable }
        cipher = EncryptedPayloadCipher(keyData: material)
    }

    func encrypt(_ data: Data) throws -> Data {
        try cipher.seal(data)
    }

    func decrypt(_ data: Data) throws -> Data {
        try cipher.open(data)
    }
}

private enum KeychainSecret {
    static func loadOrCreate(service: String, account: String) throws -> Data {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true
        ]
        var result: CFTypeRef?
        let readStatus = SecItemCopyMatching(query as CFDictionary, &result)
        if readStatus == errSecSuccess, let data = result as? Data { return data }
        guard readStatus == errSecItemNotFound else { throw EncryptedPayloadError.unavailable }

        let newSecret = Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: newSecret,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess { return newSecret }
        if addStatus == errSecDuplicateItem {
            return try loadOrCreate(service: service, account: account)
        }
        throw EncryptedPayloadError.unavailable
    }
}
