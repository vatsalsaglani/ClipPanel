import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum ArchivePasswordRequest: Identifiable {
    case export
    case `import`(Data)
    case sync(URL)

    var id: String {
        switch self {
        case .export: "export"
        case .import: "import"
        case .sync: "sync"
        }
    }

    var title: String {
        switch self {
        case .export: "Encrypt Archive"
        case .import: "Unlock Archive"
        case .sync: "Sync Encrypted Archive"
        }
    }
}

@MainActor
@Observable
final class LibraryViewState {
    var query = ""
    var items: [ClipLibraryItem] = []
    var tags: [ClipTag] = []
    var collections: [ClipCollection] = []
    var smartFilters: [ClipSmartFilter] = []
    var selectedIDs: Set<UUID> = []
    var queue: [UUID] = []
    var errorMessage: String?
    var noticeMessage: String?

    func reload(store: ClipboardStore) {
        do {
            items = try store.libraryItems()
            tags = try store.tags()
            collections = try store.collections()
            smartFilters = try store.smartFilters()
            selectedIDs = selectedIDs.intersection(Set(items.map(\.id)))
            queue = queue.filter { id in items.contains(where: { $0.id == id }) }
        } catch {
            errorMessage = "ClipPanel could not load the library."
        }
    }
}

struct LibraryRootView: View {
    private let store: ClipboardStore
    private let onCopy: (UUID) -> Void
    private let onTransform: (UUID, ClipboardTextTransformation) -> Void
    private let onPasteQueue: ([UUID]) -> Void
    @State private var state = LibraryViewState()
    @State private var newTag = ""
    @State private var newCollection = ""
    @State private var newFilterName = ""
    @State private var newFilterQuery = ""
    @State private var customCommands = CustomTextCommandStore()
    @State private var newCommandName = ""
    @State private var newCommandFind = ""
    @State private var newCommandReplacement = ""
    @State private var archivePasswordRequest: ArchivePasswordRequest?

    init(store: ClipboardStore, onCopy: @escaping (UUID) -> Void, onTransform: @escaping (UUID, ClipboardTextTransformation) -> Void, onPasteQueue: @escaping ([UUID]) -> Void) {
        self.store = store
        self.onCopy = onCopy
        self.onTransform = onTransform
        self.onPasteQueue = onPasteQueue
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $state.selectedIDs) {
                Section("Library") {
                    TextField("Search (type:image, tag:name, regex:…)", text: $state.query)
                    Button("All clips") { state.query = "" }
                    Button("Favorites") { state.query = "favorite" }
                    Button("Saved snippets") { state.query = "snippet" }
                }
                if !state.smartFilters.isEmpty {
                    Section("Smart Filters") {
                        ForEach(state.smartFilters, id: \.id) { filter in
                            Button(filter.name) { state.query = filter.query }
                        }
                    }
                }
                Section("Tags") {
                    ForEach(state.tags, id: \.id) { tag in Button(tag.name) { state.query = "tag:\(tag.name)" } }
                    HStack {
                        TextField("New tag", text: $newTag)
                        Button("+") { createTag() }.disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                Section("Collections") {
                    ForEach(state.collections, id: \.id) { collection in Button(collection.name) { state.query = "collection:\(collection.name)" } }
                    HStack {
                        TextField("New collection", text: $newCollection)
                        Button("+") { createCollection(encrypted: false) }.disabled(newCollection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("New Encrypted") { createCollection(encrypted: true) }.disabled(newCollection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                Section("Custom Commands") {
                    ForEach(customCommands.commands) { command in
                        HStack {
                            Text(command.name)
                            Spacer()
                            Button("Delete", role: .destructive) { customCommands.delete(command) }
                                .buttonStyle(.borderless)
                        }
                    }
                    TextField("Command name", text: $newCommandName)
                    TextField("Find text", text: $newCommandFind)
                    TextField("Replace with", text: $newCommandReplacement)
                    Button("Add custom replace command", action: createCustomCommand)
                        .disabled(newCommandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newCommandFind.isEmpty)
                }
            }
            .frame(minWidth: 220)
        } content: {
            List(selection: $state.selectedIDs) {
                ForEach(filteredItems) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Image(systemName: item.record.kind.systemImage).foregroundStyle(.tint)
                            Text(item.title).lineLimit(1)
                            if item.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                            if item.isSavedSnippet { Image(systemName: "bookmark.fill").foregroundStyle(.secondary) }
                            if item.isEncrypted { Image(systemName: "lock.fill").foregroundStyle(.secondary) }
                        }
                        Text(([item.record.sourceApplicationName, item.tagNames.joined(separator: ", ")].compactMap { $0 }).joined(separator: " • "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(item.id)
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    Button("Queue Selected") { enqueueSelected() }.disabled(state.selectedIDs.isEmpty)
                    Button("Paste Queue (\(state.queue.count))") { onPasteQueue(state.queue) }.disabled(state.queue.isEmpty)
                    Button("Save Filter") { createSmartFilter() }.disabled(state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Menu("Archive") {
                        Button("Import…", action: beginImport)
                        Button("Export…") { exportArchive(password: nil) }
                        Button("Export Encrypted…") { archivePasswordRequest = .export }
                        Divider()
                        Button("Sync Encrypted Archive…", action: beginEncryptedFolderSync)
                    }
                }
            }
        } detail: {
            if let item = selectedItem {
                LibraryDetailView(
                    item: item,
                    tags: state.tags,
                    collections: state.collections,
                    customCommands: customCommands.commands,
                    editableText: (try? store.record(id: item.id)).flatMap { record in try? store.text(for: record) },
                    onCopy: { onCopy(item.id) },
                    onTransform: { onTransform(item.id, $0) },
                    onCustomTransform: { runCustomCommand($0, for: item) },
                    onSaveEditedText: { saveEditedText($0, for: item) },
                    onUpdate: { title, note, saved, favorite, tagIDs, collectionIDs in
                        update(item: item, title: title, note: note, saved: saved, favorite: favorite, tagIDs: tagIDs, collectionIDs: collectionIDs)
                    }
                )
            } else {
                ContentUnavailableView("Select a clip", systemImage: "square.stack.3d.up", description: Text("Use the Library to save, edit, tag, transform, or queue clipboard records."))
            }
        }
        .frame(minWidth: 880, minHeight: 620)
        .task { state.reload(store: store) }
        .alert("Library Error", isPresented: Binding(get: { state.errorMessage != nil }, set: { if !$0 { state.errorMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(state.errorMessage ?? "") }
        .alert("ClipPanel Library", isPresented: Binding(get: { state.noticeMessage != nil }, set: { if !$0 { state.noticeMessage = nil } })) { Button("OK", role: .cancel) {} } message: { Text(state.noticeMessage ?? "") }
        .sheet(item: $archivePasswordRequest) { request in
            ArchivePasswordSheet(title: request.title) { password in
                switch request {
                case .export:
                    exportArchive(password: password)
                case .import(let data):
                    importArchive(data, password: password)
                case .sync(let folder):
                    syncEncryptedFolder(folder, password: password)
                }
            }
        }
    }

    private var filteredItems: [ClipLibraryItem] {
        let records = SearchEngine.search(state.query, in: state.items.map(\.record))
        let byID = Dictionary(uniqueKeysWithValues: state.items.map { ($0.id, $0) })
        return records.compactMap { byID[$0.id] }
    }

    private var selectedItem: ClipLibraryItem? { filteredItems.first { state.selectedIDs.contains($0.id) } }

    private func update(item: ClipLibraryItem, title: String? = nil, note: String? = nil, saved: Bool? = nil, favorite: Bool? = nil, tagIDs: [UUID]? = nil, collectionIDs: [UUID]? = nil) {
        do {
            _ = try store.updateMetadata(recordID: item.id, title: title, note: note, isSavedSnippet: saved, isFavorite: favorite, tagIDs: tagIDs, collectionIDs: collectionIDs)
            state.reload(store: store)
        } catch { state.errorMessage = "ClipPanel could not update this clip." }
    }

    private func createTag() {
        do { _ = try store.createTag(named: newTag); newTag = ""; state.reload(store: store) }
        catch { state.errorMessage = error.localizedDescription }
    }

    private func createCollection(encrypted: Bool) {
        do { _ = try store.createCollection(named: newCollection, isEncrypted: encrypted); newCollection = ""; state.reload(store: store) }
        catch { state.errorMessage = error.localizedDescription }
    }

    private func createSmartFilter() {
        if newFilterName.isEmpty { newFilterName = state.query }
        do { _ = try store.createSmartFilter(name: newFilterName, query: state.query); newFilterName = ""; state.reload(store: store) }
        catch { state.errorMessage = error.localizedDescription }
    }

    private func enqueueSelected() {
        for id in state.selectedIDs where !state.queue.contains(id) { state.queue.append(id) }
    }

    private func createCustomCommand() {
        do {
            try customCommands.create(name: newCommandName, find: newCommandFind, replacement: newCommandReplacement)
            newCommandName = ""
            newCommandFind = ""
            newCommandReplacement = ""
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func runCustomCommand(_ command: CustomTextCommand, for item: ClipLibraryItem) {
        do {
            guard let record = try store.record(id: item.id),
                  try store.createTransformedRecord(from: record, command: command) != nil else {
                state.errorMessage = "That command did not change this text clip."
                return
            }
            state.reload(store: store)
            state.noticeMessage = "Created transformed copy with \(command.name)."
        } catch {
            state.errorMessage = "ClipPanel could not run that custom command."
        }
    }

    private func saveEditedText(_ text: String, for item: ClipLibraryItem) {
        do {
            guard let record = try store.record(id: item.id),
                  try store.createEditedTextRecord(from: record, text: text) != nil else {
                state.errorMessage = "Enter text before saving a new clip."
                return
            }
            state.reload(store: store)
            state.noticeMessage = "Saved edited text as a new clip."
        } catch {
            state.errorMessage = "ClipPanel could not save the edited text."
        }
    }

    private func exportArchive(password: String?) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = password == nil ? "ClipPanel Archive.cliparchive" : "ClipPanel Encrypted Archive.cliparchive"
        panel.allowedContentTypes = [UTType(filenameExtension: "cliparchive") ?? .json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try ClipArchiveService.exportData(from: store, password: password).write(to: url, options: .atomic)
        } catch {
            state.errorMessage = "ClipPanel could not export the archive."
        }
    }

    private func beginImport() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "cliparchive") ?? .json, .json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            if ClipArchiveService.requiresPassword(for: data) {
                archivePasswordRequest = .import(data)
            } else {
                importArchive(data, password: nil)
            }
        } catch {
            state.errorMessage = "ClipPanel could not read that archive."
        }
    }

    private func importArchive(_ data: Data, password: String?) {
        do {
            let count = try ClipArchiveService.importData(data, into: store, password: password)
            state.reload(store: store)
            state.noticeMessage = count == 0 ? "The archive did not contain any clips." : "Imported \(count) clips."
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private func beginEncryptedFolderSync() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose the folder that will hold ClipPanel's encrypted sync archive."
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        archivePasswordRequest = .sync(folder)
    }

    private func syncEncryptedFolder(_ folder: URL, password: String) {
        do {
            let result = try EncryptedFolderSyncService.sync(store: store, folderURL: folder, password: password)
            state.reload(store: store)
            state.noticeMessage = result.importedRecordCount == 0
                ? "Encrypted sync archive updated."
                : "Merged \(result.importedRecordCount) clips and updated the encrypted archive."
        } catch {
            state.errorMessage = "ClipPanel could not sync that encrypted archive."
        }
    }
}

private struct ArchivePasswordSheet: View {
    let title: String
    let onConfirm: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)
            Text("The password is used only to encrypt or decrypt this archive. ClipPanel does not save it.")
                .foregroundStyle(.secondary)
            SecureField("Archive password", text: $password)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button(title) {
                    onConfirm(password)
                    dismiss()
                }
                .disabled(password.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 390)
    }
}

private struct LibraryDetailView: View {
    let item: ClipLibraryItem
    let tags: [ClipTag]
    let collections: [ClipCollection]
    let customCommands: [CustomTextCommand]
    let editableText: String?
    let onCopy: () -> Void
    let onTransform: (ClipboardTextTransformation) -> Void
    let onCustomTransform: (CustomTextCommand) -> Void
    let onSaveEditedText: (String) -> Void
    let onUpdate: (String?, String?, Bool?, Bool?, [UUID]?, [UUID]?) -> Void
    @State private var title: String
    @State private var note: String
    @State private var saved: Bool
    @State private var favorite: Bool
    @State private var tagIDs: Set<UUID>
    @State private var collectionIDs: Set<UUID>
    @State private var transformation: ClipboardTextTransformation = .trimWhitespace
    @State private var editedText: String

    init(item: ClipLibraryItem, tags: [ClipTag], collections: [ClipCollection], customCommands: [CustomTextCommand], editableText: String?, onCopy: @escaping () -> Void, onTransform: @escaping (ClipboardTextTransformation) -> Void, onCustomTransform: @escaping (CustomTextCommand) -> Void, onSaveEditedText: @escaping (String) -> Void, onUpdate: @escaping (String?, String?, Bool?, Bool?, [UUID]?, [UUID]?) -> Void) {
        self.item = item
        self.tags = tags
        self.collections = collections
        self.customCommands = customCommands
        self.editableText = editableText
        self.onCopy = onCopy
        self.onTransform = onTransform
        self.onCustomTransform = onCustomTransform
        self.onSaveEditedText = onSaveEditedText
        self.onUpdate = onUpdate
        _title = State(initialValue: item.metadata?.customTitle ?? "")
        _note = State(initialValue: item.note)
        _saved = State(initialValue: item.isSavedSnippet)
        _favorite = State(initialValue: item.isFavorite)
        _tagIDs = State(initialValue: Set(item.metadata?.tagIDs ?? []))
        _collectionIDs = State(initialValue: Set(item.metadata?.collectionIDs ?? []))
        _editedText = State(initialValue: editableText ?? "")
    }

    var body: some View {
        Form {
            Section("Clip") {
                Text(item.record.displayText).lineLimit(4)
                Button("Copy to Clipboard", action: onCopy)
            }
            if editableText != nil {
                Section("Edit Text") {
                    TextEditor(text: $editedText).frame(minHeight: 110)
                    Button("Save Edited Text as New Clip") { onSaveEditedText(editedText) }
                }
            }
            Section("Saved snippet") {
                TextField("Custom title", text: $title)
                TextEditor(text: $note).frame(minHeight: 80)
                Toggle("Saved snippet", isOn: $saved)
                Toggle("Favorite", isOn: $favorite)
                Button("Save changes") { onUpdate(title, note, saved, favorite, Array(tagIDs), Array(collectionIDs)) }
            }
            Section("Tags") {
                ForEach(tags, id: \.id) { tag in
                    Toggle(tag.name, isOn: Binding(get: { tagIDs.contains(tag.id) }, set: { enabled in
                        if enabled { tagIDs.insert(tag.id) } else { tagIDs.remove(tag.id) }
                    }))
                }
            }
            Section("Collections") {
                ForEach(collections, id: \.id) { collection in
                    Toggle(collection.name + (collection.isEncrypted ? " (Encrypted)" : ""), isOn: Binding(get: { collectionIDs.contains(collection.id) }, set: { enabled in
                        if enabled { collectionIDs.insert(collection.id) } else { collectionIDs.remove(collection.id) }
                    }))
                }
            }
            Section("Transform") {
                Picker("Operation", selection: $transformation) { ForEach(ClipboardTextTransformation.allCases) { Text($0.title).tag($0) } }
                Button("Create transformed copy") { onTransform(transformation) }
            }
            if !customCommands.isEmpty {
                Section("Custom Commands") {
                    ForEach(customCommands) { command in
                        Button(command.name) { onCustomTransform(command) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
