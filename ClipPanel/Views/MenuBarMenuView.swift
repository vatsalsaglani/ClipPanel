import SwiftUI

struct MenuBarMenuView: View {
    @Bindable var state: AppState

    var body: some View {
        Button("Show Clipboard") {
            state.onShowClipboard?()
        }

        Button("Open Library") {
            state.onShowLibrary?()
        }

        Button(state.isMonitoring ? "Pause Monitoring" : "Resume Monitoring") {
            state.onToggleMonitoring?()
        }

        Divider()

        Button("Clear Unpinned History") { state.onClearUnpinned?() }

        SettingsLink {
            Text("Settings…")
        }

        Divider()

        Button("Quit ClipPanel") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
