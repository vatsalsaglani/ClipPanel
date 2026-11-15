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

        if state.isMonitoring {
            Menu("Pause For…") {
                ForEach(MonitoringPauseDuration.allCases, id: \.self) { duration in
                    Button(duration.title) { state.onPauseMonitoring?(duration) }
                }
            }
        } else if let deadline = state.monitoringPausedUntil {
            Text("Resumes at \(deadline.formatted(date: .omitted, time: .shortened))")
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
