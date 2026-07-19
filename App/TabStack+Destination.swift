import DODAnalytics
import DODDomain
import DODFeatureCategories
import DODFeatureFeed
import DODFeatureRecipeDetail
import SwiftUI

// The `RecipeRoute` push destinations, extracted from `TabStack.swift` so that
// file stays under the SwiftLint `file_length` cap.
extension TabStack {

    @ViewBuilder
    func destination(for route: RecipeRoute) -> some View {
        switch route {
        case .recipe(let item, let autoStartCookMode):
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
                heatCoachSheet: { AnyView(NavigationStack { HeatCoachView() }) },
                // DUT-1240 — disarm the "came here to cook" flag the instant
                // Cook Mode actually presents, not on tap (too early — the
                // recipe may still be loading) or on tab switch (too late —
                // a second recipe tapped on the same Feed visit would still
                // auto-start Cook Mode). Leaves the arm intact if this
                // recipe never reaches Cook Mode, so DUT-1229's retry intent
                // still holds.
                onAutoCookModeStarted: { cookModeFindRecipeArmed = false }
            )
            .onAppear {
                Telemetry.shared.send(.screenView(name: "recipe_detail"))
            }
        case .category(let category):
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
    }
}
