import SwiftUI

struct ClipboardPanelView: View {
    @Bindable var state: ClipboardPanelState
    @FocusState private var searchFocused: Bool
    let density: PanelDensity

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search clipboard history", text: $state.query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .simultaneousGesture(TapGesture().onEnded { state.resultsHaveKeyboardFocus = false })
                    .accessibilityHint("Type to search. Down arrow selects results. Command-Y previews the selection.")
                if !state.query.isEmpty {
                    Button { state.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                }
                Button { state.togglePreview() } label: { Image(systemName: "eye") }
                    .buttonStyle(.plain)
                    .disabled(state.selectedID == nil)
                    .help("Preview selected item (Command-Y; Space when browsing results)")
                    .accessibilityLabel("Preview selected item")
                Menu {
                    ForEach(ClipboardTextTransformation.allCases) { transformation in
                        Button(transformation.title) { state.onTransformRequested?(transformation) }
                    }
                } label: { Image(systemName: "textformat") }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .disabled(!state.canTransformSelection)
                    .help("Transform selected text")
                    .accessibilityLabel("Transform selected text")
            }
            .padding(14)

            Picker("Clipboard type", selection: $state.typeFilter) {
                ForEach(ClipboardTypeFilter.allCases) { filter in Text(filter.rawValue).tag(filter) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            if let status = state.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }
            Divider()
            Group {
                if state.results.isEmpty {
                    EmptyStateView(query: state.query.isEmpty && state.typeFilter != .all ? state.typeFilter.rawValue : state.query)
                } else {
                    ScrollViewReader { proxy in
                        List(selection: Binding(get: { state.selectedID }, set: { if let id = $0 { state.select(id) } })) {
                            ForEach(Array(state.results.enumerated()), id: \.element.id) { index, item in
                                ClipboardRowView(item: item, query: state.query, density: density, shortcutNumber: index < 9 ? index + 1 : nil)
                                    .id(item.id)
                                    .tag(item.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) { state.select(item.id); state.send(.pasteOriginal) }
                                    .simultaneousGesture(TapGesture().onEnded {
                                        state.select(item.id)
                                        state.resultsHaveKeyboardFocus = true
                                        searchFocused = true
                                    })
                            }
                        }
                        .listStyle(.plain)
                        .onChange(of: state.selectedID) { _, selectedID in
                            guard let selectedID else { return }
                            // No animation queue when holding an arrow key.
                            proxy.scrollTo(selectedID)
                        }
                        .onChange(of: state.results.map(\.id)) { _, _ in
                            if let selectedID = state.selectedID { proxy.scrollTo(selectedID) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if state.isPreviewVisible {
                Divider()
                ClipboardQuickPreviewView(preview: state.preview, onClose: state.closePreview)
            }
            Divider()
            VStack(spacing: 4) {
                HStack(spacing: 12) {
                    Text("↩ Paste")
                    Text("⇧↩ Plain Text")
                    Text("⌥↩ Copy")
                    Text("⌘P Pin")
                    Spacer()
                    Text("Esc Close")
                }
                HStack {
                    Text("⌘1–9 Paste result")
                    Spacer()
                    Text(state.resultsHaveKeyboardFocus ? "Space Preview · type to search" : "↓ Browse · ⌘Y Preview")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear { searchFocused = true }
        .onChange(of: state.focusGeneration) { _, _ in searchFocused = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Clipboard history")
    }
}
