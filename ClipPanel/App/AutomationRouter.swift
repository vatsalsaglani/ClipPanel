import Foundation

enum ClipPanelAutomationRoute: Sendable, Equatable {
    case showClipboard(query: String?)
    case openLibrary
}

@MainActor
final class ClipPanelAutomationRouter {
    static let shared = ClipPanelAutomationRouter()
    var onRoute: ((ClipPanelAutomationRoute) -> Void)?

    private init() {}

    func route(_ route: ClipPanelAutomationRoute) {
        onRoute?(route)
    }

    func handle(url: URL) {
        guard url.scheme?.lowercased() == "clippanel" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        switch url.host?.lowercased() {
        case "open": route(.showClipboard(query: nil))
        case "library": route(.openLibrary)
        case "search": route(.showClipboard(query: components?.queryItems?.first(where: { $0.name == "query" })?.value))
        default: break
        }
    }
}
