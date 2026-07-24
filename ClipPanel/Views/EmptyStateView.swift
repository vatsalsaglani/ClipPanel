import SwiftUI

struct EmptyStateView: View {
    let query: String

    var body: some View {
        ContentUnavailableView(
            query.isEmpty ? "No clipboard history" : "No matching clipboard items",
            systemImage: query.isEmpty ? "clipboard" : "magnifyingglass",
            description: Text(query.isEmpty ? "Enable monitoring in Settings, then copy something to begin." : "Try a different search.")
        )
    }
}
