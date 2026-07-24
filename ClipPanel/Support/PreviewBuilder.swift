import AppKit
import Foundation

@MainActor
enum PreviewBuilder {
    static func build(payload: ClipboardPayload) -> ClipboardPreview {
        let representations = payload.items.flatMap(\.representations)
        let types = Set(representations.map(\.typeIdentifier))

        if let text = text(from: payload) {
            let normalized = normalize(text)
            let kind: ClipboardKind = types.contains(NSPasteboard.PasteboardType.URL.rawValue) ? .url :
                (types.contains(NSPasteboard.PasteboardType.html.rawValue) || types.contains(NSPasteboard.PasteboardType.rtf.rawValue) ? .richText : .text)
            return ClipboardPreview(kind: kind, displayText: normalized, searchText: normalized)
        }
        if types.contains(NSPasteboard.PasteboardType.fileURL.rawValue) {
            let names = fileNames(from: payload)
            let text = names.isEmpty ? "Files" : names.joined(separator: ", ")
            return ClipboardPreview(kind: .files, displayText: text, searchText: text)
        }
        if types.contains(NSPasteboard.PasteboardType.png.rawValue) || types.contains(NSPasteboard.PasteboardType.tiff.rawValue) {
            return ClipboardPreview(kind: .image, displayText: "Image", searchText: "image")
        }
        return ClipboardPreview(kind: .mixed, displayText: "Clipboard item", searchText: "clipboard item")
    }

    static func text(from payload: ClipboardPayload) -> String? {
        if let data = payload.data(forTypeIdentifier: NSPasteboard.PasteboardType.string.rawValue), let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let data = payload.data(forTypeIdentifier: NSPasteboard.PasteboardType.rtf.rawValue),
           let attributed = try? NSAttributedString(data: data, options: [:], documentAttributes: nil) {
            return attributed.string
        }
        if let data = payload.data(forTypeIdentifier: NSPasteboard.PasteboardType.html.rawValue),
           let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
            return attributed.string
        }
        if let data = payload.data(forTypeIdentifier: NSPasteboard.PasteboardType.URL.rawValue), let text = String(data: data, encoding: .utf8) {
            return text
        }
        return nil
    }

    private static func fileNames(from payload: ClipboardPayload) -> [String] {
        payload.items.compactMap { item in
            guard let data = item.representations.first(where: { $0.typeIdentifier == NSPasteboard.PasteboardType.fileURL.rawValue })?.data,
                  let string = String(data: data, encoding: .utf8),
                  let url = URL(string: string) else { return nil }
            return url.lastPathComponent
        }
    }

    static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func fileURLs(from payload: ClipboardPayload) -> [URL] {
        payload.items.compactMap { item in
            guard let data = item.representations.first(where: { $0.typeIdentifier == NSPasteboard.PasteboardType.fileURL.rawValue })?.data,
                  let string = String(data: data, encoding: .utf8) else { return nil }
            return URL(string: string)
        }
    }

    static func fileDetail(from payload: ClipboardPayload) -> String? {
        let urls = fileURLs(from: payload)
        guard let first = urls.first else { return nil }
        if urls.count == 1 { return first.deletingLastPathComponent().path }
        return "\(urls.count) files • \(first.deletingLastPathComponent().path)"
    }

    static func imageDetail(from payload: ClipboardPayload) -> String? {
        guard let data = payload.data(forTypeIdentifier: NSPasteboard.PasteboardType.png.rawValue)
            ?? payload.data(forTypeIdentifier: NSPasteboard.PasteboardType.tiff.rawValue),
              let image = NSImage(data: data) else { return nil }
        let width = Int(image.size.width.rounded())
        let height = Int(image.size.height.rounded())
        return "\(width) × \(height) • \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))"
    }
}

struct ClipboardPreview: Sendable, Equatable {
    let kind: ClipboardKind
    let displayText: String
    let searchText: String
}
