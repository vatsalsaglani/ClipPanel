import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MonitoringControls: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Toggle("Enable clipboard monitoring", isOn: $settings.monitoringEnabled)
        HStack {
            Menu("Pause For…") {
                ForEach(MonitoringPauseDuration.allCases, id: \.self) { duration in
                    Button(duration.title) { settings.pauseMonitoring(for: duration) }
                }
            }
            .disabled(!settings.monitoringEnabled && settings.monitoringPausedUntil == nil)
            if let deadline = settings.monitoringPausedUntil {
                Text("Resumes at \(deadline.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Resume Now") { settings.resumeMonitoring() }
            }
        }
        Text("Copies made while paused are skipped, including when monitoring resumes.")
            .font(.caption).foregroundStyle(.secondary)
    }
}

struct HistoryRetentionControls: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Picker("Delete old history", selection: $settings.historyMaximumAgeDays) {
            Text("Never (default)").tag(0)
            Text("After 1 day").tag(1)
            Text("After 7 days").tag(7)
            Text("After 30 days").tag(30)
            Text("After 90 days").tag(90)
            if ![0, 1, 7, 30, 90].contains(settings.historyMaximumAgeDays) {
                Text("After \(settings.historyMaximumAgeDays) days").tag(settings.historyMaximumAgeDays)
            }
        }
        Text("Applies immediately to history since its last copy, then checks every minute while ClipPanel runs. Pinned clips, saved snippets, favorites, and clips in collections are kept. Exports and synced archives are not changed.")
            .font(.caption).foregroundStyle(.secondary)
    }
}

struct IgnoredApplicationsSettingsView: View {
    @Bindable var settings: SettingsStore
    @State private var identifier = ""
    @State private var selectionError: String?
    @State private var runningApplications: [ApplicationChoice] = []

    var body: some View {
        Section("Ignored Applications") {
            HStack {
                Button("Choose Application…", action: chooseApplication)
                Menu("Running Applications") {
                    if runningApplications.isEmpty { Text("No other applications running") }
                    ForEach(runningApplications) { application in
                        Button(application.name) { add(application.id) }
                            .disabled(settings.ignoredBundleIdentifiers.contains(application.id))
                    }
                }
            }
            HStack {
                TextField("Bundle identifier (advanced)", text: $identifier)
                    .onSubmit { addIdentifier() }
                Button("Add", action: addIdentifier)
                    .disabled(identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let selectionError { Text(selectionError).font(.caption).foregroundStyle(.secondary) }
            ForEach(settings.ignoredBundleIdentifiers.sorted(), id: \.self) { identifier in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(applicationName(for: identifier))
                        Text(identifier).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Spacer()
                    Button("Remove") { settings.ignoredBundleIdentifiers.remove(identifier) }
                        .accessibilityLabel("Remove \(applicationName(for: identifier)) from ignored applications")
                }
            }
            Text("New copies from these apps are skipped. Existing history is kept. Apps without a bundle identifier cannot be excluded individually.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onAppear(perform: refreshApplications)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in refreshApplications() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in refreshApplications() }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Ignore an Application"
        panel.prompt = "Ignore Application"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(filePath: "/Applications", directoryHint: .isDirectory)
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let identifier = Bundle(url: url)?.bundleIdentifier else {
                selectionError = "The selected application has no bundle identifier."
                continue
            }
            add(identifier)
        }
    }

    private func addIdentifier() {
        add(identifier)
        identifier = ""
    }

    private func add(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        guard normalized != Bundle.main.bundleIdentifier else {
            selectionError = "ClipPanel already ignores its own clipboard writes."
            return
        }
        settings.ignoredBundleIdentifiers.insert(normalized)
        selectionError = nil
    }

    private func applicationName(for identifier: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else { return identifier }
        return FileManager.default.displayName(atPath: url.path)
    }

    private func refreshApplications() {
        var seen: Set<String> = []
        runningApplications = NSWorkspace.shared.runningApplications.compactMap { application in
            guard application.activationPolicy == .regular,
                  let id = application.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier,
                  seen.insert(id).inserted else { return nil }
            return ApplicationChoice(id: id, name: application.localizedName ?? id)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private struct ApplicationChoice: Identifiable {
        let id: String
        let name: String
    }
}
