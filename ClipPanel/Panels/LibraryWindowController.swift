import AppKit
import SwiftUI

@MainActor
final class LibraryWindowController {
    private var window: NSWindow?
    private(set) var priorApplication: NSRunningApplication?

    func show(store: ClipboardStore, onCopy: @escaping (UUID) -> Void, onTransform: @escaping (UUID, ClipboardTextTransformation) -> Void, onPasteQueue: @escaping ([UUID]) -> Void) {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            priorApplication = frontmost
        }
        let content = LibraryRootView(store: store, onCopy: onCopy, onTransform: onTransform, onPasteQueue: onPasteQueue)
        let window = window ?? NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 680), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "ClipPanel Library"
        window.contentView = NSHostingView(rootView: content)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
