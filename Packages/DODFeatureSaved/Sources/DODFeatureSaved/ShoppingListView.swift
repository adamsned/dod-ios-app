import DODDesignSystem
import DODSupport
import SwiftUI

/// The aisle-grouped shopping-list surface (US-39).
///
/// Spec trace: AC-39.1 (empty state — `EmptyState` with the `cart` glyph),
/// AC-39.4 (aisle grouping + store-walk order + per-aisle glyph headers),
/// AC-39.5 (per-row check toggle + strikethrough), AC-39.11 (VoiceOver row
/// labels). CL-82 (this UI slice: per-recipe rows, ephemeral check +
/// already-have state, mock-data-driven; the Saved-tab entry button, the
/// recipe-picker, the `UIActivityViewController` share, the clear-all toolbar,
/// SwiftData persistence, and analytics are all T-680c).
///
/// **Grouping (CL-80 / CL-82):** rows group by the six-case
/// ``IngredientAisleClassifier/Aisle`` shipped by T-680a, in `allCases`
/// declaration order; empty aisles render no section. The section header is
/// inline here — the standalone `AisleSectionHeader` DesignSystem primitive
/// lands with T-680c.
public struct ShoppingListView: View {

    @State private var viewModel: ShoppingListViewModel

    public init(viewModel: ShoppingListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        content
            .background(DODColor.surface)
            .navigationTitle("Shopping List")
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isEmpty {
            EmptyState(
                systemImage: "cart",
                title: "Your shopping list is empty",
                message: "Tap a saved recipe and add its ingredients here"
            )
        } else {
            list
                .scrollContentBackground(.hidden)
                .background(DODColor.surface)
        }
    }

    /// The sectioned list. `.insetGrouped` is iOS-only; the macOS `swift test`
    /// slice falls back to the default grouped style.
    private var list: some View {
        let list = List {
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.items) { item in
                        row(for: item)
                    }
                } header: {
                    AisleHeader(aisle: section.aisle)
                }
            }
        }
        #if os(iOS)
        return list.listStyle(.insetGrouped)
        #else
        return list
        #endif
    }

    @ViewBuilder
    private func row(for item: ShoppingListViewModel.Item) -> some View {
        let checked = viewModel.isChecked(item)
        HStack(alignment: .firstTextBaseline, spacing: DODSpacing.sm) {
            Button {
                viewModel.toggleChecked(item)
            } label: {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(checked ? DODColor.accent : DODColor.labelSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("shopping-list-row-toggle")
            .accessibilityLabel(checked ? "Mark as still need" : "Mark as already have")

            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                Text(item.ingredientText)
                    .dodFont(DODType.body)
                    .strikethrough(checked)
                    .foregroundStyle(checked ? DODColor.labelSecondary : DODColor.label)
                Text(item.recipeTitle)
                    .dodFont(DODType.caption)
                    .strikethrough(checked)
                    .foregroundStyle(DODColor.labelSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, DODSpacing.xxs)
        .listRowBackground(DODColor.surfaceElevated)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: item))
        .accessibilityAddTraits(checked ? .isSelected : [])
        // AC-39.5 / CL-82 — the trailing "I already have this" affordance.
        .swipeActions(edge: .trailing) {
            Button {
                viewModel.markAlreadyHave(item)
            } label: {
                Label("I already have this", systemImage: "checkmark.circle")
            }
            .tint(DODColor.accent)
        }
    }

    /// AC-39.11 — `"<ingredient text>, <aisle>, from <recipe title>"`.
    private func accessibilityLabel(for item: ShoppingListViewModel.Item) -> String {
        "\(item.ingredientText), \(AisleHeader.displayName(item.aisle)), from \(item.recipeTitle)"
    }
}

// MARK: - Inline aisle section header (T-680c hoists this to a DesignSystem primitive)

private struct AisleHeader: View {
    let aisle: IngredientAisleClassifier.Aisle

    var body: some View {
        Label {
            Text(Self.displayName(aisle))
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
        } icon: {
            Image(systemName: Self.glyph(aisle))
                .foregroundStyle(DODColor.accent)
        }
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
    }

    /// AC-39.4 display names for the six shipped aisles. `meat` renders as
    /// "Meat & Seafood" per AC-39.4 (the logic core folds seafood into `.meat`
    /// per CL-80).
    static func displayName(_ aisle: IngredientAisleClassifier.Aisle) -> String {
        switch aisle {
        case .produce: "Produce"
        case .meat: "Meat & Seafood"
        case .dairy: "Dairy"
        case .pantry: "Pantry"
        case .spices: "Spices"
        case .other: "Other"
        }
    }

    /// AC-39.4 per-aisle SF Symbol glyphs (mapped for the six shipped cases).
    /// Pantry uses `archivebox` rather than AC-39.4's `cabinet` because
    /// `cabinet` is not a valid SF Symbol (it would render blank); T-680c can
    /// revisit if a real pantry glyph ships.
    static func glyph(_ aisle: IngredientAisleClassifier.Aisle) -> String {
        switch aisle {
        case .produce: "leaf"
        case .meat: "fish"
        case .dairy: "drop"
        case .pantry: "archivebox"
        case .spices: "flame"
        case .other: "cart"
        }
    }
}

#Preview("Shopping list — mock data") {
    NavigationStack {
        ShoppingListView(viewModel: .mock)
    }
}

#Preview("Shopping list — empty") {
    NavigationStack {
        ShoppingListView(viewModel: ShoppingListViewModel(items: []))
    }
}
