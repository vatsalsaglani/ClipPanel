import Foundation

enum ClipboardAccessState: String, Sendable {
    case ready
    case needsUserAction
    case denied
}

enum AutoPastePermissionState: String, Sendable {
    case granted
    case unavailable
}
