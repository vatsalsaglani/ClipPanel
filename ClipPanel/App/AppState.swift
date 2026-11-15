import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var isMonitoring = true
    var monitoringPausedUntil: Date?
    var statusMessage = "Monitoring clipboard history"
    var hasCompletedOnboarding = false
    var onShowClipboard: (() -> Void)?
    var onShowLibrary: (() -> Void)?
    var onPauseMonitoring: ((MonitoringPauseDuration) -> Void)?
    var onToggleMonitoring: (() -> Void)?
    var onClearUnpinned: (() -> Void)?
    var onClearAll: (() -> Void)?
    var onRequestAutoPaste: (() -> Void)?
    var onRequestAccessibility: (() -> Void)?
    var onOpenDataFolder: (() -> Void)?
    var onResetSettings: (() -> Void)?
}
