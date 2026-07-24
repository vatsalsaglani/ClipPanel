import KeyboardShortcuts

@MainActor
extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.q, modifiers: [.control]))
}

@MainActor
final class GlobalShortcutService {
    func register(onToggle: @escaping @MainActor () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .togglePanel) {
            Task { @MainActor in onToggle() }
        }
    }
}
