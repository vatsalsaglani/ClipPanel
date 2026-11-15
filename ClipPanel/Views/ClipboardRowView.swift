import AppKit
import SwiftUI

struct ClipboardRowView: View {
    let item: ClipboardSearchItem
    let query: String
    let density: PanelDensity
    var shortcutNumber: Int? = nil

    var body: some View {
        HStack(spacing: 10) {
            if item.kind == .image, let data = item.thumbnailData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .accessibilityLabel("Image thumbnail")
            } else if item.kind == .files, let fileURL = item.fileURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: fileURL.path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .accessibilityLabel("File")
            } else {
                Image(systemName: item.kind.systemImage)
                    .frame(width: iconSize, height: iconSize)
                    .foregroundStyle(.tint)
                    .accessibilityLabel(item.kind.displayName)
            }
            VStack(alignment: .leading, spacing: 3) {
                highlightedTitle
                    .lineLimit(2)
                HStack(spacing: 4) {
                    if let source = item.sourceApplicationName { Text(source) }
                    Text(item.kind.displayName)
                    if let detail = item.detailText { Text(detail).lineLimit(1) }
                    Text(RelativeTimeFormatter.string(since: item.lastCopiedAt))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let shortcutNumber {
                Text("⌘\(shortcutNumber)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Command \(shortcutNumber) to paste")
            }
            if item.isPinned { Image(systemName: "pin.fill").font(.caption).accessibilityLabel("Pinned") }
        }
        .padding(.vertical, density == .compact ? 2 : 5)
    }

    private var iconSize: CGFloat { density == .compact ? 22 : 28 }

    private var highlightedTitle: Text {
        let value = item.displayText.isEmpty ? item.kind.displayName : String(item.displayText.prefix(240))
        let ranges = SearchEngine.displayMatchRanges(query: query, in: value)
        var attributed = AttributedString(value)
        for range in ranges {
            if let attributedRange = Range(range, in: attributed) {
                attributed[attributedRange].backgroundColor = .accentColor.opacity(0.28)
                attributed[attributedRange].foregroundColor = .primary
            }
        }
        return Text(attributed)
    }
}
