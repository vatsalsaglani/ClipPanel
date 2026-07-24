import Foundation

struct ScreenGeometry: Equatable, Sendable {
    let frame: CGRect
    let visibleFrame: CGRect
}

enum PanelPositioner {
    static func frame(panelSize: CGSize, pointer: CGPoint, screens: [ScreenGeometry], anchor: PanelAnchor = .mousePointer, gap: CGFloat = 12) -> CGRect {
        let screen = screens.first(where: { $0.frame.contains(pointer) }) ?? screens.first ?? ScreenGeometry(frame: .zero, visibleFrame: .zero)
        let visible = screen.visibleFrame
        let width = min(panelSize.width, max(0, visible.width))
        let height = min(panelSize.height, max(0, visible.height))
        if anchor == .screenCenter {
            return CGRect(x: visible.midX - width / 2, y: visible.midY - height / 2, width: width, height: height)
        }
        var origin = CGPoint(x: pointer.x + gap, y: pointer.y - height - gap)
        if origin.x + width > visible.maxX { origin.x = pointer.x - width - gap }
        if origin.y < visible.minY { origin.y = pointer.y + gap }
        origin.x = min(max(origin.x, visible.minX), max(visible.minX, visible.maxX - width))
        origin.y = min(max(origin.y, visible.minY), max(visible.minY, visible.maxY - height))
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }
}
