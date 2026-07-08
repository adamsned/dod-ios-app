import DODDesignSystem
import DODDomain
import SwiftUI

/// The recipe-picker sheet for building a shopping list from saved recipes
/// (US-39 / AC-39.3).
///
/// Spec trace: AC-39.3 (add from multiple saved recipes — the bulk path),
/// CL-85 decision 2 (a modal multi-select sheet over the Saved view-model's
/// already-loaded recipes; "Confirm" enabled at ≥1 selection; selection is
/// ephemeral `@State`, discarded on cancel). The picker reuses the recipes the
/// Saved tab has already fetched — no second network call (REG-23 / AC-39.12),
/// so it is instant and works offline against the pinned saved-recipe cache.
///
/// DUT-487 / T-906 — the picker now lives inside ``ShoppingListView`` (was
/// presented builder-first from ``SavedView``). On "Confirm" the selected
/// `[Recipe]` is handed back via ``onBuild`` and the sheet dismisses; the
/// hosting ``ShoppingListView`` calls ``ShoppingListViewModel/add(recipes:)``
/// so the same view fills / appends in place instead of pushing a new screen.
struct ShoppingListBuilderSheet: View {

    let recipes: [Recipe]
    /// Called with the user's selected recipes (in `recipes` order) when the
    /// user taps "Confirm".
    let onBuild: ([Recipe]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<Recipe.ID> = []

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Make Shopping List")
                #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("shopping-builder-cancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        // DUT-487 / T-906 — visible label is now "Confirm"; the
                        // sheet dismisses back to the same ShoppingListView, which
                        // populates / appends in place (the "Build List" action
                        // itself moved to the list's empty state).
                        Button("Confirm") { build() }
                            .disabled(selectedIDs.isEmpty)
                            .accessibilityIdentifier("shopping-builder-build")
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if recipes.isEmpty {
            // Defensive — the entry button is hidden when there are no saved
            // recipes, so this is normally unreachable.
            EmptyState(
                systemImage: "bookmark",
                title: "No Saved Recipes",
                message: "Save a recipe first, then build a shopping list from it."
            )
        } else {
            list
        }
    }

    private var list: some View {
        let list = List {
            Section {
                ForEach(recipes) { recipe in
                    row(for: recipe)
                }
            } header: {
                Text(
                    "Pick the recipes you're shopping for. We'll combine their ingredients "
                        + "into one list, sorted by store aisle so you can shop in one loop."
                )
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .textCase(nil)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DODColor.surface)
        #if os(iOS)
        return list.listStyle(.insetGrouped)
        #else
        return list
        #endif
    }

    @ViewBuilder
    private func row(for recipe: Recipe) -> some View {
        let selected = selectedIDs.contains(recipe.id)
        Button {
            toggle(recipe)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: DODSpacing.sm) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(selected ? DODColor.accent : DODColor.labelSecondary)

                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    Text(recipe.title)
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                    if !recipe.ingredients.isEmpty {
                        Text(ingredientCountLabel(recipe.ingredients.count))
                            .dodFont(DODType.caption)
                            .foregroundStyle(DODColor.labelSecondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, DODSpacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(DODColor.surfaceElevated)
        // DUT — match the Shopping List row's check-off tap (`.selection`); keyed
        // to THIS row's own `selected` so the haptic fires on the tap that flips it.
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recipe.title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("shopping-builder-row")
    }

    private func ingredientCountLabel(_ count: Int) -> String {
        count == 1 ? "1 ingredient" : "\(count) ingredients"
    }

    // MARK: - Selection

    private func toggle(_ recipe: Recipe) {
        if selectedIDs.contains(recipe.id) {
            selectedIDs.remove(recipe.id)
        } else {
            selectedIDs.insert(recipe.id)
        }
    }

    private func build() {
        let selected = recipes.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        onBuild(selected)
        dismiss()
    }
}

#Preview("Shopping list builder") {
    ShoppingListBuilderSheet(
        recipes: [
            Recipe(
                id: 1,
                slug: "pot-roast",
                title: "Dutch Oven Pot Roast",
                excerpt: "",
                canonicalURL: URL(string: "https://www.dutchovendaddy.com/1/") ?? URL(filePath: "/"),
                publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
                ingredients: [.init(text: "3 lb beef chuck roast"), .init(text: "1 yellow onion")]
            ),
            Recipe(
                id: 2,
                slug: "tacos",
                title: "Skillet Chicken Tacos",
                excerpt: "",
                canonicalURL: URL(string: "https://www.dutchovendaddy.com/2/") ?? URL(filePath: "/"),
                publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
                ingredients: [.init(text: "1 lb chicken thighs")]
            ),
        ],
        onBuild: { _ in }
    )
}
