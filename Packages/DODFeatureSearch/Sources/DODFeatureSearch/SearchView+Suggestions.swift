import DODDesignSystem
import DODDomain
import SwiftUI

/// v2 Search overhaul (2/3) — the type-ahead suggestions list rendered under
/// the search field while it's focused. Each row is a matching recipe title
/// from the local cached-title pool; tapping one runs that search
/// (`viewModel.applySuggestion`). Split out of `SearchView.swift` so that file
/// stays under SwiftLint's 400-line `file_length` cap, matching the
/// `+IngredientSection` split pattern.
extension SearchView {

    /// The suggestions list. Capped-height so a long pool never pushes the
    /// results off-screen; scrolls internally if it overflows.
    var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.suggestions.enumerated()), id: \.element) { index, suggestion in
                suggestionRow(suggestion)
                if index < viewModel.suggestions.count - 1 {
                    Divider()
                        .overlay(DODColor.surfaceDivider)
                        .padding(.leading, DODSpacing.md)
                }
            }
        }
        .padding(.horizontal, DODSpacing.md)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search-suggestions")
    }

    /// One suggestion row: a leading magnifying-glass glyph (burnt-orange
    /// accent) and the title. Full-width 44pt tap target routes to
    /// `applySuggestion`.
    private func suggestionRow(_ suggestion: String) -> some View {
        Button {
            viewModel.applySuggestion(suggestion)
        } label: {
            HStack(spacing: DODSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DODColor.burntOrange)
                    .accessibilityHidden(true)
                Text(suggestion)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("search-suggestion-row")
        .accessibilityLabel("Search \(suggestion)")
    }
}
