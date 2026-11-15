import AppKit

@MainActor
enum AppMaintenanceService {
    static let releasesURL = URL(string: "https://github.com/vatsalsaglani/ClipPanel/releases")!

    static func versionDescription(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (build \($0))" } ?? version
    }

    static func openReleases() -> Bool {
        NSWorkspace.shared.open(releasesURL)
    }

    static func restart() throws {
        // Wait for the old process to exit before opening the exact same bundle,
        // so shortcut registration and the local store have a single owner.
        // Paths are positional arguments, never interpolated into shell code.
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = [
            "-c",
            "count=0; while /bin/kill -0 \"$1\" 2>/dev/null; do count=$((count + 1)); [ \"$count\" -lt 100 ] || exit 1; /bin/sleep 0.1; done; exec /usr/bin/open -n \"$2\"",
            "clippanel-restart",
            String(ProcessInfo.processInfo.processIdentifier),
            Bundle.main.bundleURL.path
        ]
        helper.standardInput = FileHandle.nullDevice
        helper.standardOutput = FileHandle.nullDevice
        helper.standardError = FileHandle.nullDevice
        try helper.run()
        NSApp.terminate(nil)
    }
}
