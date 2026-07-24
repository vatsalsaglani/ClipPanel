import Foundation
import Observation

/// A deliberately safe custom command: it is a local find-and-replace transformation, not an
/// arbitrary shell process. This keeps user-authored automation useful without silently granting
/// clipboard data to another executable.
struct CustomTextCommand: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var find: String
    var replacement: String

    init(id: UUID = UUID(), name: String, find: String, replacement: String) {
        self.id = id
        self.name = name
        self.find = find
        self.replacement = replacement
    }
}

@MainActor
@Observable
final class CustomTextCommandStore {
    private static let key = "customTextCommands"
    private let defaults: UserDefaults
    var commands: [CustomTextCommand] { didSet { save() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        commands = (try? JSONDecoder().decode([CustomTextCommand].self, from: defaults.data(forKey: Self.key) ?? Data())) ?? []
    }

    func create(name: String, find: String, replacement: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !find.isEmpty else { throw ClipboardStoreError.emptyName }
        commands.append(CustomTextCommand(name: trimmedName, find: find, replacement: replacement))
        commands.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func delete(_ command: CustomTextCommand) {
        commands.removeAll { $0.id == command.id }
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(commands), forKey: Self.key)
    }
}
