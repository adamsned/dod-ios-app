import DODDesignSystem
import SwiftUI

/// DUT-1339 — the horizontal row of type/state filter chips that sits under the
/// collections shelf on the Saved tab. Narrows the list to All / Recipes /
/// Articles / Downloaded. The chip visual language matches ``CollectionsShelf``
/// (same `Capsule` fill, caption font, accent selection) so the two rows read
/// as one coherent set.
///
/// Pure presentation: it takes the current selection and a callback from
/// ``SavedView`` and holds no state of its own, so it renders identically in
/// previews and snapshots.
struct SavedFilterChips: View {

    let selected: SavedViewModel.SavedTypeFilter
    let onSelect: (SavedViewModel.SavedTypeFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DODSpacing.xs) {
                ForEach(SavedViewModel.SavedTypeFilter.allCases, id: \.self) { filter in
                    chip(
                        title: filter.title,
                        isSelected: selected == filter,
                        action: { onSelect(filter) }
                    )
                    .accessibilityIdentifier("dod.saved.filterChip.\(filter.rawValue)")
                }
            }
            .padding(.horizontal, DODSpacing.md)
            .padding(.vertical, DODSpacing.xs)
        }
        .accessibilityIdentifier("dod.saved.filterChips")
    }

    /// Matches ``CollectionsShelf``'s chip so the filter row and the collections
    /// shelf share one visual language (DUT-1339 house rule).
    private func chip(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(DODType.caption)
                .lineLimit(1)
                .padding(.horizontal, DODSpacing.sm)
                .padding(.vertical, DODSpacing.xs)
                .foregroundStyle(isSelected ? DODColor.labelOnAccent : DODColor.label)
                .background(
                    Capsule().fill(isSelected ? DODColor.accent : DODColor.surfaceElevated)
                )
        }
        .buttonStyle(.plain)
    }
}
