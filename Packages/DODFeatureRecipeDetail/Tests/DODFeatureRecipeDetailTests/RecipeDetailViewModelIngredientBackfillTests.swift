import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 view-model coverage for the DUT-53 cache-hit ingredient self-heal.
///
/// A recipe cached with empty `ingredients` but `hasDetail == true` (it has
/// instructions) takes the `onAppear()` cache-hit fast path
/// (`hydrateCachedRecipe`) and, pre-DUT-53, never re-parsed — so a parser
/// improvement (the DUT-42 WPRM-card ingredient fallback) or a site-content
/// fix never reached an already-cached row. `backfillIngredientsIfEmpty()`
/// closes that gap: when the displayed (cached) recipe has no ingredients it
/// re-fetches + re-parses in the background and, if the re-parse now recovers
/// ingredients, persists them and swaps them into the live recipe.
///
/// The helper is fire-and-forget (REG-37: it must not hold `onAppear()` open
/// across a network call) and fail-silent / non-downgrading — offline, fetch
/// error, and a still-empty re-parse all leave the cached view untouched.
///
/// Spec trace: DUT-53 (follow-up to DUT-42), mirrors T-736 / REG-37.
@MainActor
@Suite("RecipeDetailViewModel.backfillIngredientsIfEmpty (DUT-53)")
struct RecipeDetailIngredientBackfillTests {

    /// Happy path: cache-hit, recipe has instructions but no ingredients
    /// (`hasDetail == true`), online, and a background re-parse now recovers
    /// ingredients (models DUT-42's WPRM fallback applying to an already-
    /// cached row). After `onAppear()` the live recipe AND the persisted
    /// cache both carry the recovered ingredients.
    @Test func cacheHitWithEmptyIngredientsBackfillsViaReparse() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = true
        // hasDetail == true (instructions present) but ingredients empty —
        // the exact shape that takes the cache-hit path yet should self-heal.
        dependencies.cachedRecipes[310] = RecipeDetailTestFixtures.makeRecipe(
            id: 310,
            withDetail: true,
            ingredients: []
        )
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 310,
            withDetail: true,
            ingredients: [.init(text: "black beans"), .init(text: "sweet corn")]
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 310)

        await viewModel.onAppear()
        await Self.drain(until: { viewModel.recipe?.ingredients.isEmpty == false })

        #expect(viewModel.loadState == .ready)
        // Re-parse recovered the ingredients and swapped them into the recipe.
        #expect(viewModel.recipe?.ingredients.count == 2)
        #expect(viewModel.recipe?.ingredients.contains { $0.text == "black beans" } == true)
        // ...and persisted them so the next cache read is already complete.
        #expect(dependencies.cachedRecipes[310]?.ingredients.count == 2)
        // No user-visible error — the cached view was valid the whole time.
        #expect(viewModel.snackbarMessage == nil)
    }

    /// Guard: a cached recipe that already HAS ingredients must never be
    /// re-parsed — the backfill returns before any fetch, so the only HTML
    /// fetch is the blurb refresh (no redundant second fetch, no churn).
    @Test func cacheHitWithIngredientsDoesNotReparse() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = true
        dependencies.cachedRecipes[311] = RecipeDetailTestFixtures.makeRecipe(
            id: 311,
            withDetail: true  // -> [salt, pepper]
        )
        // If the backfill wrongly fired, it would swap in this single item.
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 311,
            withDetail: true,
            ingredients: [.init(text: "WRONG")]
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 311)

        await viewModel.onAppear()
        await Self.settle()

        #expect(viewModel.recipe?.ingredients.count == 2)
        #expect(viewModel.recipe?.ingredients.contains { $0.text == "WRONG" } == false)
        // Only the blurb refresh fetched (1); the backfill short-circuited.
        #expect(dependencies.fetchCount == 1)
    }

    /// Offline: the backfill (like the blurb refresh) is gated on
    /// `isOnline()`, so it never issues a fetch and the cached — still
    /// empty — view stays exactly as-is. Issuing a call we know will fail
    /// wastes battery and adds spurious error-log noise.
    @Test func cacheHitEmptyIngredientsOfflineSkipsBackfill() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = false
        dependencies.cachedRecipes[312] = RecipeDetailTestFixtures.makeRecipe(
            id: 312,
            withDetail: true,
            ingredients: []
        )
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 312,
            withDetail: true,
            ingredients: [.init(text: "black beans")]
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 312)

        await viewModel.onAppear()
        await Self.settle()

        #expect(viewModel.loadState == .ready)
        #expect(dependencies.fetchCount == 0)
        #expect(viewModel.recipe?.ingredients.isEmpty == true)
    }

    /// Fetch error: a transient network failure during the background
    /// re-fetch is swallowed (`try?`). The cached view stays on screen with
    /// its empty ingredients, NO snackbar surfaces, and the load state is
    /// unaffected. The next online open re-attempts.
    @Test func cacheHitEmptyIngredientsFetchErrorFailsSilently() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.online = true
        dependencies.fetchShouldFail = true
        dependencies.cachedRecipes[313] = RecipeDetailTestFixtures.makeRecipe(
            id: 313,
            withDetail: true,
            ingredients: []
        )
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 313,
            withDetail: true,
            ingredients: [.init(text: "black beans")]
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 313)

        await viewModel.onAppear()
        await Self.settle()

        #expect(viewModel.loadState == .ready)
        #expect(viewModel.recipe?.ingredients.isEmpty == true)
        // Background-refresh failures must NOT trigger a user-visible snackbar.
        #expect(viewModel.snackbarMessage == nil)
    }

    // MARK: - Helpers

    /// Yield the MainActor until `condition` holds or the spin cap is hit.
    /// The fake dependencies settle each await in one hop, so the fire-and-
    /// forget background Task converges within a handful of yields; the cap
    /// is a generous backstop that turns a logic regression into a failed
    /// assertion rather than a hung suite.
    static func drain(until condition: @MainActor () -> Bool, spins: Int = 500) async {
        var iteration = 0
        while !condition(), iteration < spins {
            await Task.yield()
            iteration += 1
        }
    }

    /// Drain a fixed number of yields to let a no-op background Task run to
    /// completion (used by the cases that assert the backfill did NOT change
    /// state).
    static func settle(spins: Int = 200) async {
        await drain(until: { false }, spins: spins)
    }

    static func makeViewModel(
        dependencies: RecipeDetailDependencies,
        listItemID: Int
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: listItemID),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(listItemID)/")
                ?? URL(filePath: "/"),
            dependencies: dependencies
        )
    }
}
