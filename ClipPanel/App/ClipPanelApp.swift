import AppKit
import SwiftUI

private enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipPanel")
            ?? NSImage()
        image.isTemplate = true
        return image
    }()
}

@main
struct ClipPanelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        if !AppRuntime.isRunningTests { ClipPanelShortcuts.updateAppShortcutParameters() }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenuView(state: appDelegate.coordinator.appState)
        } label: {
            Image(nsImage: MenuBarIcon.image)
                .accessibilityLabel("ClipPanel")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsRootView()
                .environment(appDelegate.coordinator.appState)
                .environment(appDelegate.coordinator.settings)
        }
    }
}
