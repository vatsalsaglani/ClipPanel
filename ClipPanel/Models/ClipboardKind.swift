import Foundation

enum ClipboardKind: String, Codable, CaseIterable, Sendable {
    case text
    case url
    case richText
    case image
    case files
    case mixed

    var displayName: String {
        switch self {
        case .text: "Text"
        case .url: "URL"
        case .richText: "Rich Text"
        case .image: "Image"
        case .files: "Files"
        case .mixed: "Mixed"
        }
    }

    var systemImage: String {
        switch self {
        case .text: "text.alignleft"
        case .url: "link"
        case .richText: "doc.richtext"
        case .image: "photo"
        case .files: "folder"
        case .mixed: "square.stack.3d.up"
        }
    }
}

enum PanelDensity: String, CaseIterable, Sendable {
    case comfortable
    case compact

    var title: String {
        switch self {
        case .comfortable: "Comfortable"
        case .compact: "Compact"
        }
    }
}
