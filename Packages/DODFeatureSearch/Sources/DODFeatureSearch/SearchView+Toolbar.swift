import DODDesignSystem
import DODDomain
import SwiftUI

/// The Search tab's layout-toggle toolbar button, split out of `SearchView.swift`
/// so that file stays under SwiftLint's 400-line `file_length` cap (relocated by
/// T-779 / DUT-85, which added the recent-search focus wiring to the main file).
extension SearchView {

    /// US-38 / AC-38.1 / CL-64 (T-650): the layout-toggle button. Same
    /// shape as `FeedView.layoutToggleToolbarButton` — current-state
    /// icon convention (CL-64.1), destination-aware accessibility hint.
    var layoutToggleToolbarButton: some View {
        let layout = RecipeListLayout(rawValue: layoutRaw) ?? .gallery
        return Button {
            var next = layout
            next.toggle()
            layoutRaw = next.rawValue
        } label: {
            Image(systemName: layout.toggleIconName)
                .accessibilityLabel(layout.currentStateAccessibilityLabel)
                .accessibilityHint(layout.destinationActionHint)
        }
        .accessibilityIdentifier("search-toolbar-layout-toggle")
    }
}
