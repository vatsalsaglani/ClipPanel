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
    func requestAutoPasteAccess(openSettingsIfNeeded: Bool = false) -> AutoPastePermissionState {
        guard !CGPreflightPostEventAccess() else { return .granted }
        _ = CGRequestPostEventAccess()
        let state = autoPasteState
        if state != .granted, openSettingsIfNeeded,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            // macOS may decline to show another permission prompt after the
            // first request. Give explicit Settings/onboarding actions a path
            // to the approval screen even in that case.
            NSWorkspace.shared.open(url)
        }
        return state
    }
}
