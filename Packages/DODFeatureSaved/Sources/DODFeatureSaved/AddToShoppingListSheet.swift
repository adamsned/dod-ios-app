import DODDesignSystem
import DODDomain
import DODSupport
import SwiftUI

/// The ingredient-selection sheet shown when adding a recipe to the Shopping
/// List (DUT-535 — pick / deselect which ingredients to add).
///
/// Spec trace: DUT-535 (supersedes DUT-534's immediate add-all from Recipe
/// Detail). The recipe's ingredients are exploded + classified into candidate
/// rows (via ``AddToShoppingListSelection`` → ``ShoppingListViewModel/rows(from:)``,
/// CL-77), presented as a checklist grouped by store aisle (matching the
/// Shopping List's ``AisleHeader`` sections). Every row starts selected, so the
/// default confirm reproduces add-all in one tap; a Select All / None toolbar
/// toggle flips the whole list; the confirm reads "Add N items" (live) and is
/// disabled at zero. Cancel dismisses with no change.
///
/// Lives in `DODFeatureSaved` (alongside the appender + row model it needs);
/// Recipe Detail presents it through an injected closure seam (the App
/// composition root builds it), since `DODFeatureRecipeDetail` does not — and
/// must not — depend on `DODFeatureSaved`.
public struct AddToShoppingListSheet: View {

    @State private var selection: AddToShoppingListSelection

    /// The appender the confirm routes the selected rows through (DUT-535 —
    /// ``ShoppingListAppender/addToShoppingList(rows:)``). Type-erased to the
    /// protocol so the App wires the live impl; tests pass a fake.
    private let appender: any ShoppingListAppender

    /// Called with the append result AFTER the rows are persisted, so the host
    /// (Recipe Detail) can surface its "Added N ingredients" Snackbar. The sheet
    /// dismisses itself; the host does not need to.
    private let onComplete: (AddToShoppingListResult) -> Void

    @Environment(\.dismiss) private var dismiss

    /// DUT-693 — true while ``confirm()`` awaits the append. Without it a quick
    /// double-tap on the confirm button fires two overlapping appends (and two
    /// `onComplete` calls, so the host shows its toast twice); the disable while
    /// in-flight makes the confirm single-shot.
    @State private var isSubmitting = false

    public init(
        recipe: Recipe,
        appender: any ShoppingListAppender,
        onComplete: @escaping (AddToShoppingListResult) -> Void
    ) {
        _selection = State(initialValue: AddToShoppingListSelection(recipe: recipe))
        self.appender = appender
        self.onComplete = onComplete
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Add to Shopping List")
                #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("dod.detail.addToShoppingList.cancel")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(selection.isAllSelected ? "Select None" : "Select All") {
                            selection.toggleSelectAll()
                        }
                        .accessibilityIdentifier("dod.detail.addToShoppingList.selectAll")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(confirmTitle) { confirm() }
                            .disabled(selection.selectedCount == 0 || isSubmitting)
                            .accessibilityIdentifier("dod.detail.addToShoppingList.confirm")
                    }
                }
        }
    }

    /// "Add N items" — live-updating with the selected count; singular-aware.
    private var confirmTitle: String {
        let count = selection.selectedCount
        return count == 1 ? "Add 1 Item" : "Add \(count) Items"
    }

    @ViewBuilder
    private var content: some View {
        if selection.candidates.isEmpty {
            // Defensive — the Detail button stays disabled for a zero-ingredient
            // recipe, so this is normally unreachable.
            EmptyState(
                systemImage: "cart",
                title: "No Ingredients",
                message: "This recipe doesn't list any ingredients to add."
            )
        } else {
            list
        }
    }

    private var list: some View {
        let list = List {
            ForEach(selection.groups) { group in
                Section {
                    ForEach(group.items) { item in
                        row(for: item)
                    }
                } header: {
                    AisleHeader(aisle: group.aisle)
                }
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
    private func row(for item: ShoppingListViewModel.Item) -> some View {
        let selected = selection.isSelected(item)
        Button {
            selection.toggle(item)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: DODSpacing.sm) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(selected ? DODColor.accent : DODColor.labelSecondary)

                Text(item.ingredientText)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)

                Spacer(minLength: 0)
            }
            .padding(.vertical, DODSpacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(DODColor.surfaceElevated)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.ingredientText)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("dod.detail.addToShoppingList.row")
    }

    private func confirm() {
        // DUT-693 — guard against a double-tap firing two appends. Flip before
        // the await so the button is disabled for the whole in-flight window.
        guard !isSubmitting else { return }
        isSubmitting = true
        let rows = selection.selectedRows
        Task {
            let result = await appender.addToShoppingList(rows: rows)
            onComplete(result)
            dismiss()
        }
    }
}

#Preview("Add to Shopping List — selection") {
    AddToShoppingListSheet(
        recipe: Recipe(
            id: 1,
            slug: "pot-roast",
            title: "Dutch Oven Pot Roast",
            excerpt: "",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/1/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: [
                .init(text: "3 lb beef chuck roast"),
                .init(text: "1 yellow onion, quartered"),
                .init(text: "4 carrots, peeled"),
                .init(text: "2 cups beef broth"),
                .init(text: "1 tsp salt"),
            ]
        ),
        appender: LiveShoppingListAppender(store: nil),
        onComplete: { _ in }
    )
}
