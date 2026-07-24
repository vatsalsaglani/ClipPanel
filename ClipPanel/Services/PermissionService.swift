import AppKit
import CoreGraphics

@MainActor
final class PermissionService {
    var clipboardAccessState: ClipboardAccessState {
        guard #available(macOS 15.4, *) else { return .ready }
        return switch NSPasteboard.general.accessBehavior {
        case .alwaysAllow: .ready
        case .alwaysDeny: .denied
        case .ask, .default: .needsUserAction
        @unknown default: .needsUserAction
        }
    }

    var autoPasteState: AutoPastePermissionState {
        CGPreflightPostEventAccess() ? .granted : .unavailable
    }

    /// Call only from an explicit auto-paste action, onboarding, or Settings.
    func requestAutoPasteAccess() -> AutoPastePermissionState {
        guard !CGPreflightPostEventAccess() else { return .granted }
        _ = CGRequestPostEventAccess()
        return autoPasteState
    }
}
