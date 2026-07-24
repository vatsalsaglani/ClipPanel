import CoreGraphics
import ApplicationServices
import KeyboardShortcuts
import SwiftUI

struct SettingsRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(SettingsStore.self) private var settings
    @State private var section = 0
    @State private var launchError: String?
    @State private var confirmClearAll = false
    @State private var ignoredBundleIdentifier = ""
    @State private var confirmReset = false

    var body: some View {
        TabView(selection: $section) {
            general.tabItem { Label("General", systemImage: "gear") }.tag(0)
            behavior.tabItem { Label("Behavior", systemImage: "command") }.tag(1)
            history.tabItem { Label("History", systemImage: "clock.arrow.circlepath") }.tag(2)
            privacy.tabItem { Label("Privacy", systemImage: "lock") }.tag(3)
            about.tabItem { Label("About", systemImage: "info.circle") }.tag(4)
        }
        .padding(20)
        .frame(width: 560, height: 410)
        .onChange(of: settings.launchAtLogin) { _, enabled in
            do { try LaunchAtLoginService().setEnabled(enabled); launchError = nil }
            catch { launchError = "Launch at login could not be changed." }
        }
        .alert("Clear all clipboard history?", isPresented: $confirmClearAll) {
            Button("Clear All", role: .destructive) { appState.onClearAll?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes pinned and unpinned ClipPanel history from this Mac.")
        }
        .alert("Reset ClipPanel settings?", isPresented: $confirmReset) {
            Button("Reset Settings", role: .destructive) { appState.onResetSettings?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This restores default preferences and pauses clipboard monitoring. Stored history is not deleted.")
        }
    }

    private var general: some View {
        @Bindable var settings = settings
        return Form {
            Section("Shortcut") { KeyboardShortcuts.Recorder("Show Clipboard:", name: .togglePanel) }
            Section("Monitoring") { Toggle("Enable clipboard monitoring", isOn: $settings.monitoringEnabled) }
            Section("Launch") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Show Dock icon", isOn: $settings.showDockIcon)
                if let launchError { Text(launchError).foregroundStyle(.secondary) }
            }
        }.formStyle(.grouped)
    }
    private var behavior: some View {
        @Bindable var settings = settings
        return Form {
            Toggle("Auto-paste after restoring", isOn: $settings.autoPasteEnabled)
            Toggle("Keep copy-only fallback enabled", isOn: $settings.copyOnlyFallbackEnabled)
            HStack { Text("Paste delay"); Slider(value: $settings.pasteDelay, in: SettingsValidation.pasteDelayRange); Text(settings.pasteDelay, format: .number.precision(.fractionLength(2))) }
            Picker("Panel placement", selection: $settings.panelAnchor) {
                ForEach(PanelAnchor.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Panel density", selection: $settings.panelDensity) {
                ForEach(PanelDensity.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Toggle("Keep search query between openings", isOn: $settings.keepSearchQuery)
        }.formStyle(.grouped)
    }
    private var history: some View {
        @Bindable var settings = settings
        return Form {
            Stepper("Unpinned history limit: \(settings.historyLimit)", value: $settings.historyLimit, in: SettingsValidation.historyRange)
            Stepper("Maximum payload: \(settings.maximumPayloadBytes / 1_024 / 1_024) MB", value: $settings.maximumPayloadBytes, in: SettingsValidation.payloadRange, step: 1_024 * 1_024)
            Button("Clear Unpinned History", role: .destructive) { appState.onClearUnpinned?() }
            Button("Clear All History…", role: .destructive) { confirmClearAll = true }
        }.formStyle(.grouped)
    }
    private var privacy: some View {
        @Bindable var settings = settings
        return Form {
            LabeledContent("Clipboard monitoring", value: settings.monitoringEnabled ? "Enabled" : "Paused")
            LabeledContent("Auto-paste", value: CGPreflightPostEventAccess() ? "Permission available" : "Copy-only fallback")
            Button("Request Auto-Paste Permission") { appState.onRequestAutoPaste?() }
            LabeledContent("Text caret placement", value: AXIsProcessTrustedWithOptions(nil) ? "Permission available" : "Optional Accessibility permission")
            Button("Request Accessibility Permission") { appState.onRequestAccessibility?() }
            Toggle("Ignore transient clipboard markers", isOn: $settings.ignoreTransient)
            Toggle("Ignore concealed clipboard markers", isOn: $settings.ignoreConcealed)
            Toggle("Ignore autogenerated clipboard markers", isOn: $settings.ignoreAutoGenerated)
            Toggle("Include Universal Clipboard", isOn: $settings.includeUniversalClipboard)
            HStack {
                TextField("Ignored bundle identifier", text: $ignoredBundleIdentifier)
                Button("Add") {
                    let trimmed = ignoredBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    settings.ignoredBundleIdentifiers.insert(trimmed)
                    ignoredBundleIdentifier = ""
                }
            }
            if !settings.ignoredBundleIdentifiers.isEmpty {
                ForEach(settings.ignoredBundleIdentifiers.sorted(), id: \.self) { identifier in
                    HStack { Text(identifier); Spacer(); Button("Remove") { settings.ignoredBundleIdentifiers.remove(identifier) } }
                }
            }
            Text("History stays on this Mac. Optional folder sync is explicit and encrypted; ClipPanel does not use analytics or a cloud account.").foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }
    private var about: some View {
        Form {
            LabeledContent("Version", value: "1.0")
            Text("ClipPanel is a local-only clipboard history utility.")
            Text("Third-party acknowledgement: KeyboardShortcuts by Sindre Sorhus.").foregroundStyle(.secondary)
            Button("Open Application Support Folder") { appState.onOpenDataFolder?() }
            Button("Reset Settings…", role: .destructive) { confirmReset = true }
        }.formStyle(.grouped)
    }
}
