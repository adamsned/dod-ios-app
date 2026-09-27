import DODDesignSystem
import DODDomain
import SwiftUI

/// DUT-105 — the horizontal shelf of collection chips that sits above the Saved
/// list. The leading "All Saved" chip clears the filter (the flat list the tab
/// has always shown); each collection chip filters the grid to that cookbook;
/// the trailing "New Collection" chip opens the create sheet. A long-press on a
/// collection chip offers Rename / Delete.
///
/// Pure presentation: it takes the data and closures from ``SavedView`` and
/// holds no state of its own, so it renders identically in previews and
/// snapshots.
struct CollectionsShelf: View {

    let collections: [RecipeCollection]
    let selectedID: UUID?
    let onSelectAll: () -> Void
    let onSelect: (RecipeCollection) -> Void
    let onNew: () -> Void
    let onRename: (RecipeCollection) -> Void
    let onDelete: (RecipeCollection) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DODSpacing.xs) {
                chip(title: "All Saved", isSelected: selectedID == nil, action: onSelectAll)
                    .accessibilityIdentifier("dod.saved.collectionChip.all")
                ForEach(collections) { collection in
                    collectionChip(collection)
                }
                newChip
            }
            .padding(.horizontal, DODSpacing.md)
            .padding(.vertical, DODSpacing.xs)
        }
        .accessibilityIdentifier("dod.saved.collectionsShelf")
    }

    private func collectionChip(_ collection: RecipeCollection) -> some View {
        chip(
            title: "\(collection.name)  \(collection.recipeCount)",
            isSelected: selectedID == collection.id,
            action: { onSelect(collection) }
        )
        .accessibilityIdentifier("dod.saved.collectionChip")
        .contextMenu {
            Button {
                onRename(collection)
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete(collection)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var newChip: some View {
        Button(action: onNew) {
            Label("New Collection", systemImage: "plus")
                .font(DODType.caption)
                .padding(.horizontal, DODSpacing.sm)
                .padding(.vertical, DODSpacing.xs)
                .foregroundStyle(DODColor.accent)
                .overlay(
                    Capsule().strokeBorder(DODColor.accent, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dod.saved.newCollection")
    }

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
