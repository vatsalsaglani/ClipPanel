import AppKit
import ImageIO
import SwiftUI

@MainActor
struct ClipboardQuickPreview {
    static let textLimit = 100_000
    static let imagePixelLimit = 1_200
    let text: String?
    let image: NSImage?
    let isTextTruncated: Bool

    init(item: ClipboardSearchItem, payload: ClipboardPayload?) {
        let fullText = payload.flatMap(PreviewBuilder.text(from:)) ?? (item.kind == .image ? nil : item.searchText)
        if let fullText {
            let end = fullText.index(fullText.startIndex, offsetBy: Self.textLimit, limitedBy: fullText.endIndex) ?? fullText.endIndex
            text = String(fullText[..<end])
            isTextTruncated = end < fullText.endIndex
        } else {
            text = nil
            isTextTruncated = false
        }
        let imageData = payload?.data(forTypeIdentifier: NSPasteboard.PasteboardType.png.rawValue)
            ?? payload?.data(forTypeIdentifier: NSPasteboard.PasteboardType.tiff.rawValue)
            ?? item.thumbnailData
        if let imageData, let source = CGImageSourceCreateWithData(imageData as CFData, nil),
           let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
               kCGImageSourceCreateThumbnailFromImageAlways: true,
               kCGImageSourceCreateThumbnailWithTransform: true,
               kCGImageSourceThumbnailMaxPixelSize: Self.imagePixelLimit,
               kCGImageSourceShouldCacheImmediately: true
           ] as CFDictionary) {
            image = NSImage(cgImage: thumbnail, size: .zero)
        } else { image = nil }
    }
}

struct ClipboardQuickPreviewView: View {
    let preview: ClipboardQuickPreview?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Preview").font(.headline)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close preview")
            }
            if let preview {
                if let image = preview.image {
                    Image(nsImage: image).resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 200)
                        .accessibilityLabel("Clipboard image preview")
                } else if let text = preview.text {
                    ScrollView([.vertical, .horizontal]) {
                        Text(text).font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    if preview.isTextTruncated {
                        Text("Showing the first 100,000 characters. Pasting keeps the complete original.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Preview unavailable. The original clipboard item is preserved.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(height: 230)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Selected clipboard preview")
    }
}
