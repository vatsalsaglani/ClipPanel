import OSLog

enum AppLogger {
    private static let subsystem = "com.clippanel.app"
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let monitor = Logger(subsystem: subsystem, category: "clipboard-monitor")
    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let panel = Logger(subsystem: subsystem, category: "panel")
    static let search = Logger(subsystem: subsystem, category: "search")
    static let paste = Logger(subsystem: subsystem, category: "paste")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")
}
