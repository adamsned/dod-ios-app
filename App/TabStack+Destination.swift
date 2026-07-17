import DODAnalytics
import DODDomain
import DODFeatureCategories
import DODFeatureFeed
import DODFeatureRecipeDetail
import DODFeatureSearch
import Foundation
import SwiftUI

// The pushed-destination builder for a tab's `NavigationStack`, extracted from
// `TabStack.swift` so that file stays under the SwiftLint `file_length` cap.
//
// v2 Search overhaul (2/3) — Search is no longer PUSHED onto the Feed stack;
// it's presented as a bottom-up modal (`.sheet`) that hosts its OWN
// `NavigationStack`. So the recipe / category destination builders are
// parameterized on a `push` closure: the Feed tab pushes onto its `path`; the
// search modal pushes onto its own `searchPath` (see `searchModal`). Both reuse
// the exact same `RecipeDetailView` / `CategoryRecipesView` wiring.
extension TabStack {

    @ViewBuilder
    func destination(for route: RecipeRoute) -> some View {
        switch route {
        case .recipe(let item, let autoStartCookMode):
            recipeDestination(item: item, autoStartCookMode: autoStartCookMode) { path.append($0) }
        case .category(let category):
            categoryDestination(category) { path.append($0) }
        }
    }

    /// v2 Search overhaul (2/3) — the destination builder for the search
    /// modal's OWN `NavigationStack`. Identical to `destination(for:)` but
    /// pushes onto `searchPath` (the sheet's inner stack) so tapping a search
    /// result / browse-category navigates WITHIN the modal, and Back returns to
    /// the search results — it never disturbs the Feed's stack behind the sheet.
    @ViewBuilder
    func searchModalDestination(for route: RecipeRoute) -> some View {
        switch route {
        case .recipe(let item, let autoStartCookMode):
            recipeDestination(item: item, autoStartCookMode: autoStartCookMode) {
                searchPath.append($0)
            }
        case .category(let category):
            categoryDestination(category) { searchPath.append($0) }
        }
    }

    @ViewBuilder
    private func recipeDestination(
        item: RecipeListItem,
        autoStartCookMode: Bool,
        // v2 Search overhaul (2/3) — the caller supplies where a "related recipe"
        // tap pushes (the Feed's `path` or the search modal's `searchPath`).
        push: @escaping (RecipeRoute) -> Void
    ) -> some View {
        let canonical =
            item.canonicalURL
            ?? URL(string: "https://www.dutchovendaddy.com/") ?? URL(filePath: "/")
        RecipeDetailView(
            viewModel: RecipeDetailViewModel(
                listItem: item,
                canonicalURL: canonical,
                dependencies: dependencies.recipeDetailDependencies(),
                // DUT-546 — inject the shared store so a block on one open
                // recipe screen live-hides that author on another.
                commentModeration: commentModeration
            ),
            onSelectRelated: { related in push(.recipe(item: related)) },
            autoStartCookMode: autoStartCookMode,
            // DUT-534 — the Snackbar "View" action opens the Shopping List.
            openShoppingList: openShoppingList,
            // DUT-535 — present the ingredient-selection sheet on "Add to
            // Shopping List" (pick which ingredients), replacing the DUT-534
            // immediate add-all.
            addToShoppingListSheet: dependencies.addToShoppingListSheetBuilder(),
            // T-912 / DUT-551 — the per-recipe Heat Coach nudge routes to the
            // hub tool; the Cook Mode heat-step shortcut presents Heat Coach
            // as a sheet over the full-screen cover (a tab switch would be
            // invisible beneath it).
            openHeatCoach: openHeatCoach,
            heatCoachSheet: { AnyView(NavigationStack { HeatCoachView() }) }
        )
        .onAppear {
            Telemetry.shared.send(.screenView(name: "recipe_detail"))
        }
    }

    @ViewBuilder
    private func categoryDestination(
        _ category: DODDomain.Category,
        push: @escaping (RecipeRoute) -> Void
    ) -> some View {
        CategoryRecipesView(
            viewModel: CategoryRecipesViewModel(
                category: category,
                dependencies: dependencies.categoriesDependencies()
            ),
            onSelect: { item in push(.recipe(item: item)) },
            onSave: { item, report in
                Task {
                    let didSave = await Self.saveFromCard(
                        item: item,
                        store: dependencies.store,
                        publisher: dependencies.savedWidgetPublisher()
                    )
                    report(didSave)  // DUT-629 — revert optimistic flip on failure
                    if !didSave { saveErrorMessage = Self.saveFailedMessage }  // DUT-693
                }
            }
        )
        .onAppear {
            Telemetry.shared.send(.screenView(name: "category_recipes"))
        }
    }

    /// v2 Search overhaul (2/3) — the Search screen, presented as a BOTTOM-UP
    /// modal (`.sheet` in `TabStack.body`, driven by `showSearch`) instead of a
    /// pushed screen. It hosts its OWN `NavigationStack` (path `searchPath`) so a
    /// tapped result opens the recipe detail — and a browse-category opens its
    /// screen — WITHIN the sheet, with Back returning to the results. Dismissal
    /// is the header's "Done" (`onDone`) plus the sheet's interactive drag.
    /// Reuses the SAME `RecipeDetailView` / `CategoryRecipesView` builders the
    /// Feed stack uses (via `searchModalDestination`). Surprise Me lives on this
    /// page's idle state. No `onOpenSettings`: a focused modal, and the Feed root
    /// already hosts the Settings gear. `DODFeatureFeed` can't import
    /// `DODFeatureSearch` (CL-122), so this App-shell host bridges the two.
    @ViewBuilder
    var searchModal: some View {
        NavigationStack(path: $searchPath) {
            SearchView(
                viewModel: SearchViewModel(dependencies: dependencies.searchDependencies()),
                onSelect: { item in searchPath.append(.recipe(item: item)) },
                onSave: { item, report in
                    Task {
                        let didSave = await Self.saveFromCard(
                            item: item,
                            store: dependencies.store,
                            publisher: dependencies.savedWidgetPublisher()
                        )
                        report(didSave)  // DUT-629 — revert optimistic flip on failure
                        if !didSave { saveErrorMessage = Self.saveFailedMessage }  // DUT-693
                    }
                },
                // T-799 / CL-193: browse-category tap → push the category's recipes
                // onto the MODAL's stack (resolved via `searchModalDestination`).
                onSelectCategory: { category in searchPath.append(.category(category)) },
                // DUT-534 Part 2 — the card snackbar's "View" opens the Shopping List.
                openShoppingList: openShoppingList,
                // The sheet dismisses via the header's top-right "Done".
                onDone: { showSearch = false }
            )
            .navigationDestination(for: RecipeRoute.self) { route in
                searchModalDestination(for: route)
            }
            .onAppear {
                Telemetry.shared.send(.screenView(name: "search"))
            }
        }
        // A search page wants the full sheet height; keep it a single large
        // detent so iOS never opens it as a partial (medium) card. The
        // interactive drag-to-dismiss stays available.
        .presentationDetents([.large])
    }
}
