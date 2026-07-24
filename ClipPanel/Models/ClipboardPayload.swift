import Foundation

struct ClipboardPayload: Codable, Sendable, Equatable {
    var items: [ClipboardPayloadItem]

    var byteCount: Int {
        items.flatMap(\.representations).reduce(0) { $0 + $1.data.count }
    }

    /// A deterministic representation used for identity only. It sorts types inside an item
    /// but preserves item boundaries and item order, both of which affect paste fidelity.
    var canonicalData: Data {
        var data = Data()
        for item in items {
            data.appendLength(item.representations.count)
            for representation in item.representations.sorted(by: { $0.typeIdentifier < $1.typeIdentifier }) {
                data.appendString(representation.typeIdentifier)
                data.appendLength(representation.data.count)
                data.append(representation.data)
            }
        }
        return data
    }

    func data(forTypeIdentifier identifier: String) -> Data? {
        items.lazy
            .flatMap(\.representations)
            .first(where: { $0.typeIdentifier == identifier })?
            .data
    }
}

struct ClipboardPayloadItem: Codable, Sendable, Equatable {
    var representations: [ClipboardRepresentation]
}

struct ClipboardRepresentation: Codable, Sendable, Equatable {
    var typeIdentifier: String
    var data: Data
}

private extension Data {
    mutating func appendLength(_ value: Int) {
        var bigEndian = UInt64(value).bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { append(contentsOf: $0) }
    }

    mutating func appendString(_ value: String) {
        let encoded = Data(value.utf8)
        appendLength(encoded.count)
        append(encoded)
    }
}
