import AppKit
import Foundation

enum ClipPanelCLI {
    static func run(arguments: [String]) -> Int32 {
        guard let command = arguments.first else {
            print(usage)
            return 0
        }
        let url: URL?
        switch command {
        case "open": url = URL(string: "clippanel://open")
        case "library": url = URL(string: "clippanel://library")
        case "search":
            let query = arguments.dropFirst().joined(separator: " ")
            guard !query.isEmpty else { fputs("clipctl search requires a query.\\n", stderr); return 64 }
            var components = URLComponents()
            components.scheme = "clippanel"
            components.host = "search"
            components.queryItems = [URLQueryItem(name: "query", value: query)]
            url = components.url
        case "help", "--help", "-h":
            print(usage)
            return 0
        default:
            fputs("Unknown command: \(command)\\n\(usage)\\n", stderr)
            return 64
        }
        guard let url, NSWorkspace.shared.open(url) else {
            fputs("ClipPanel is not installed or its automation URL is unavailable.\\n", stderr)
            return 69
        }
        return 0
    }

    private static let usage = """
    Usage: clipctl <command> [query]
      open                 Open the clipboard panel
      library              Open saved snippets and collections
      search <query>       Open the panel with a local-history search
    """
}

exit(ClipPanelCLI.run(arguments: Array(CommandLine.arguments.dropFirst())))
