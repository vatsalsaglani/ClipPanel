import AppKit

struct SourceApplication: Sendable, Equatable {
    var bundleIdentifier: String?
    var name: String?
}

@MainActor
enum SourceApplicationService {
    static func currentSource() -> SourceApplication? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        return SourceApplication(bundleIdentifier: application.bundleIdentifier, name: application.localizedName)
    }
}
