import SwiftUI

struct ClipboardPanelView: View {
    @Bindable var state: ClipboardPanelState
    let density: PanelDensity

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search clipboard history", text: $state.query)
                    .textFieldStyle(.plain)
                if !state.query.isEmpty {
                    Button { state.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                }
                if let status = state.statusMessage { Image(systemName: "exclamationmark.circle").help(status) }
            }
            .padding(14)

            Divider()
            Group {
                if state.results.isEmpty {
                    EmptyStateView(query: state.query)
                } else {
                    ScrollViewReader { proxy in
                        List(selection: Binding(get: { state.selectedID }, set: { if let id = $0 { state.select(id) } })) {
                            ForEach(state.results) { item in
                                ClipboardRowView(item: item, query: state.query, density: density)
                                    .id(item.id)
                                    .tag(item.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) { state.send(.pasteOriginal) }
                            }
                        }
                        .listStyle(.plain)
                        .onChange(of: state.selectedID) { _, selectedID in
                            guard let selectedID else { return }
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(selectedID, anchor: .center)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack(spacing: 12) {
                Text("↩ Paste")
                Text("⇧↩ Plain Text")
                Text("⌥↩ Copy")
                Text("⌘P Pin")
                Spacer()
                Text("Esc Close")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Clipboard history")
    }
}
