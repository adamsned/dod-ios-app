import DODDesignSystem
import DODDomain
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

    /// DUT-487 / T-906 — the recipe picker is now owned here (was
    /// ``SavedView``'s builder-sheet-first path). Presented from the empty
    /// state's "Build List" button and the populated "Add recipes" `+`; on
    /// confirm the picked recipes append via ``ShoppingListViewModel/add(recipes:)``
    /// so the same view fills / grows in place instead of pushing a new screen.
    @State private var isPickingRecipes = false

    /// The saved recipes the picker chooses from. Empty when the list opens
    /// standalone (e.g. the `dod://shopping-list` deep link); ``SavedView``
    /// keeps this fed so the Saved-tab entry can pick straight away.
    private let recipes: [Recipe]

    /// DUT-487 — hydrate a picked recipe's `ingredients` before building rows.
    /// A saved recipe returned by `RecipeStore.savedRecipes()` often has EMPTY
    /// `ingredients` until its detail has been fetched, so building straight
    /// from the picker produced ZERO rows (the list stayed empty). ``SavedView``
    /// passes `viewModel.recipeWithIngredients`, which fetches + parses + caches
    /// the detail on demand. Defaults to identity so previews / tests / the
    /// deep-link-without-deps path still compile (they just skip hydration).
    private let hydrate: @Sendable (Recipe) async -> Recipe

    /// DUT-487 — true while the confirm handler hydrates the picked recipes (a
    /// network fetch per never-opened recipe), so a subtle progress overlay
    /// covers the list and interaction is disabled until the rows are built.
    @State private var isBuilding = false

    public init(
        viewModel: ShoppingListViewModel,
        recipes: [Recipe] = [],
        hydrate: @escaping @Sendable (Recipe) async -> Recipe = { $0 }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.recipes = recipes
        self.hydrate = hydrate
    }

    public var body: some View {
        content
            .background(DODColor.surface)
            .navigationTitle("Shopping List")
            .toolbar { shareToolbar }
            .toolbar { addToolbar }
            .sheet(isPresented: $isPickingRecipes) {
                ShoppingListBuilderSheet(recipes: recipes) { selected in
                    build(from: selected)
                }
            }
            // DUT-487 — while hydrating the picked recipes, dim + disable the
            // list and float a spinner so the user sees the list is building
            // (a never-opened recipe needs a detail fetch to get its ingredients).
            .disabled(isBuilding)
            .overlay {
                if isBuilding {
                    buildingOverlay
                }
            }
    }

    /// DUT-487 — subtle progress overlay shown while ``build(from:)`` hydrates
    /// the picked recipes. Matches the app's scrim style (a translucent
    /// `DODColor.surface` veil + a centered `ProgressView`).
    private var buildingOverlay: some View {
        ZStack {
            DODColor.surface.opacity(0.6)
            ProgressView()
                .controlSize(.large)
                .tint(DODColor.accent)
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("shopping-list-building")
        .accessibilityLabel("Building shopping list")
    }

    /// DUT-487 — hydrate every picked recipe's ingredients (concurrently), then
    /// append their rows. A saved recipe often arrives with empty `ingredients`
    /// (detail never fetched), so hydrating first is what makes the list
    /// actually populate. `isBuilding` gates the overlay for the fetch window.
    private func build(from selected: [Recipe]) {
        isBuilding = true
        Task {
            let hydrated = await withTaskGroup(of: Recipe.self) { group in
                for recipe in selected {
                    group.addTask { await hydrate(recipe) }
                }
                var out: [Recipe] = []
                for await recipe in group {
                    out.append(recipe)
                }
                return out
            }
            viewModel.add(recipes: hydrated)
            isBuilding = false
        }
    }

    /// DUT-487 / T-906 — the populated-state "Add recipes" `+`. Opens the same
    /// picker as the empty state; confirming appends the new recipes' rows
    /// (AC-39.3). Hidden while empty (the empty state carries its own primary
    /// "Build List" button).
    @ToolbarContentBuilder
    private var addToolbar: some ToolbarContent {
        if !viewModel.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPickingRecipes = true
                } label: {
                    Label("Add recipes", systemImage: "plus")
                }
                .accessibilityIdentifier("shopping-list-add")
            }
        }
    }

    /// AC-39.7 / CL-85 decision 3 — "Share via iMessage". A SwiftUI `ShareLink`
    /// wrapping the plain-text payload from ``ShoppingListFormatter`` (no
    /// `MessageUI` dependency, per AC-39.7 + CL-72 — the system share sheet
    /// routes to iMessage / AirDrop / Mail / Notes / Copy). Hidden in the empty
    /// state (nothing to share, mirroring AC-39.1's hide-share posture). The
    /// shared text is the still-need subset — checked + already-have rows are
    /// excluded (CL-85's recorded deviation from CL-72's full-list snapshot).
    @ToolbarContentBuilder
    private var shareToolbar: some ToolbarContent {
        if !viewModel.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: ShoppingListFormatter.shareText(viewModel)) {
                    Label("Share via iMessage", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("shopping-list-share")
                .accessibilityLabel("Share shopping list")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isEmpty {
            // DUT-487 / T-906 — empty-first: the list opens empty and offers a
            // primary "Build List" button that presents the recipe picker, so
            // building a list is the obvious next step from right here.
            EmptyState(
                systemImage: "cart",
                title: "Your shopping list is empty",
                message: "Build a list from your saved recipes and we'll sort everything by store aisle.",
                action: .init(title: "Build List") {
                    isPickingRecipes = true
                }
            )
            .accessibilityIdentifier("shopping-list-build")
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
        ShoppingListView(viewModel: ShoppingListViewModel())
    }
}
