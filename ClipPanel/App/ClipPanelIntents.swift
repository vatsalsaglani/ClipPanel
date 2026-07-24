import AppIntents

struct OpenClipPanelIntent: AppIntent {
    static let title: LocalizedStringResource = "Open ClipPanel"
    static let description = IntentDescription("Open ClipPanel's clipboard panel")
    // `supportedModes` is macOS 26+. Keep the macOS 14 baseline by using the compatible
    // foreground handoff declaration that App Intents continues to support for in-app intents.
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { ClipPanelAutomationRouter.shared.route(.showClipboard(query: nil)) }
        return .result()
    }
}

struct SearchClipPanelIntent: AppIntent {
    static let title: LocalizedStringResource = "Search ClipPanel"
    static let description = IntentDescription("Open ClipPanel and search local clipboard history")
    static let openAppWhenRun = true

    @Parameter(title: "Search query")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Search ClipPanel for \\.$query")
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run { ClipPanelAutomationRouter.shared.route(.showClipboard(query: query)) }
        return .result()
    }
}

struct OpenClipPanelLibraryIntent: AppIntent {
    static let title: LocalizedStringResource = "Open ClipPanel Library"
    static let description = IntentDescription("Open ClipPanel's saved snippets and collections")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { ClipPanelAutomationRouter.shared.route(.openLibrary) }
        return .result()
    }
}

struct ClipPanelShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenClipPanelIntent(),
            phrases: ["Open \(.applicationName)", "Show clipboard in \(.applicationName)"],
            shortTitle: "Open Clipboard",
            systemImageName: "clipboard"
        )
        AppShortcut(
            intent: SearchClipPanelIntent(),
            phrases: ["Search clipboard in \(.applicationName)"],
            shortTitle: "Search Clipboard",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: OpenClipPanelLibraryIntent(),
            phrases: ["Open library in \(.applicationName)"],
            shortTitle: "Open Library",
            systemImageName: "square.stack.3d.up"
        )
    }
}
