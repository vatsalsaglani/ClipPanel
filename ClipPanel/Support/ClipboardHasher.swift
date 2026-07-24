import CryptoKit
import Foundation

enum ClipboardHasher {
    static func hash(payload: ClipboardPayload) -> String {
        SHA256.hash(data: payload.canonicalData).map { String(format: "%02x", $0) }.joined()
    }
}
