import AppKit
import Foundation

enum ClipboardTextTransformation: String, CaseIterable, Identifiable, Sendable {
    case trimWhitespace
    case uppercase
    case lowercase
    case titlecase
    case stripFormatting
    case cleanURL

    var id: String { rawValue }
    var title: String {
        switch self {
        case .trimWhitespace: "Trim whitespace"
        case .uppercase: "UPPERCASE"
        case .lowercase: "lowercase"
        case .titlecase: "Title Case"
        case .stripFormatting: "Strip formatting"
        case .cleanURL: "Clean URL"
        }
    }
}

@MainActor
enum ClipboardTransformationService {
    static func transform(_ payload: ClipboardPayload, using transformation: ClipboardTextTransformation) -> ClipboardPayload? {
        guard let originalText = PreviewBuilder.text(from: payload) else { return nil }
        let text: String
        switch transformation {
        case .trimWhitespace: text = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .uppercase: text = originalText.uppercased()
        case .lowercase: text = originalText.lowercased()
        case .titlecase: text = originalText.capitalized
        case .stripFormatting: text = originalText
        case .cleanURL: text = cleanedURL(originalText) ?? originalText
        }
        let representation = ClipboardRepresentation(typeIdentifier: NSPasteboard.PasteboardType.string.rawValue, data: Data(text.utf8))
        return ClipboardPayload(items: [ClipboardPayloadItem(representations: [representation])])
    }

    static func transform(_ payload: ClipboardPayload, using command: CustomTextCommand) -> ClipboardPayload? {
        guard let text = PreviewBuilder.text(from: payload), !command.find.isEmpty else { return nil }
        let transformed = text.replacingOccurrences(of: command.find, with: command.replacement)
        guard transformed != text else { return nil }
        let representation = ClipboardRepresentation(typeIdentifier: NSPasteboard.PasteboardType.string.rawValue, data: Data(transformed.utf8))
        return ClipboardPayload(items: [ClipboardPayloadItem(representations: [representation])])
    }

    private static func cleanedURL(_ value: String) -> String? {
        guard var components = URLComponents(string: value), components.scheme != nil else { return nil }
        components.fragment = nil
        components.queryItems = components.queryItems?.filter { item in
            let key = item.name.lowercased()
            return !(key.hasPrefix("utm_") || ["fbclid", "gclid", "mc_cid", "mc_eid"].contains(key))
        }
        return components.url?.absoluteString
    }
}
