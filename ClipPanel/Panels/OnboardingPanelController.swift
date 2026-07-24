import AppKit
import SwiftUI

@MainActor
final class OnboardingPanelController {
    private var window: NSWindow?

    func show(settings: SettingsStore, permissionService: PermissionService, finish: @escaping () -> Void) {
        let content = OnboardingView(settings: settings, permissionService: permissionService, finish: { [weak self] in
            self?.window?.close()
            finish()
        })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 510), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Welcome to ClipPanel"
        window.center()
        window.contentView = NSHostingView(rootView: content)
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
