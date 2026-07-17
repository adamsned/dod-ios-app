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
// v2 Search overhaul (1/3) added the `.search` case here — Search is no longer a
// tab; the Feed header's magnifying glass PUSHES it, resolving through the same
// `navigationDestination(for: RecipeRoute.self)` the recipe / category routes use.
extension TabStack {

    @ViewBuilder
    func destination(for route: RecipeRoute) -> some View {
        switch route {
        case .recipe(let item, let autoStartCookMode):
            recipeDestination(item: item, autoStartCookMode: autoStartCookMode)
        case .category(let category):
            categoryDestination(category)
        case .search:
            searchDestination
        }
    }

    @ViewBuilder
    private func recipeDestination(item: RecipeListItem, autoStartCookMode: Bool) -> some View {
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
            onSelectRelated: { related in path.append(.recipe(item: related)) },
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
    private func categoryDestination(_ category: DODDomain.Category) -> some View {
        CategoryRecipesView(
            viewModel: CategoryRecipesViewModel(
                category: category,
                dependencies: dependencies.categoriesDependencies()
            ),
            onSelect: { item in path.append(.recipe(item: item)) },
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

    /// v2 Search overhaul (1/3) — the Search screen, PUSHED here instead of
    /// living in its own tab. Reuses the SAME wiring the retired `.search` tab
    /// case used (onSelect / onSave=saveFromCard / onSelectCategory → push
    /// `.category` / openShoppingList). SearchView keeps its own
    /// `DODScreenHeader("Search")`; pushed, it also gets a system back chevron.
    /// Surprise Me now lives on this page's idle state. No `onOpenSettings`: the
    /// pushed screen has a back chevron, so it shows no header gear (the Feed
    /// root already hosts the Settings gear).
    @ViewBuilder
    private var searchDestination: some View {
        SearchView(
            viewModel: SearchViewModel(dependencies: dependencies.searchDependencies()),
            onSelect: { item in path.append(.recipe(item: item)) },
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
            // T-799 / CL-193: browse-category tap → push the category's recipes,
            // resolved via the shared `navigationDestination` → `CategoryRecipesView`.
            onSelectCategory: { category in path.append(.category(category)) },
            // DUT-534 Part 2 — the card snackbar's "View" opens the Shopping List.
            openShoppingList: openShoppingList
        )
        .onAppear {
            Telemetry.shared.send(.screenView(name: "search"))
        }
    }
}
