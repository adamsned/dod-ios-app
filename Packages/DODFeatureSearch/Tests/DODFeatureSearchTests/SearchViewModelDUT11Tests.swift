import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

/// DUT-11 — L1 coverage for the ingredient-name search tier. Searching an
/// ingredient term ("ground beef") surfaces recipes that USE the ingredient
/// (from the local `CachedIngredient` index) in a labeled tier
/// (`ingredientItems`) that is distinct from, and deduped against, the
/// title/category results (`items`). The tier works offline and keeps the
/// user on a `.results` screen even when the title tier is empty.
///
/// Split into its own file so `SearchViewModelTests.swift` stays under
/// SwiftLint's `file_length` / `type_body_length` caps — mirrors the
/// T-637 / T-643 split pattern.
@MainActor
@Suite("SearchViewModel DUT-11 (ingredient tier)") struct SearchViewModelDUT11Tests {

    @Test func ingredientHitsSurfaceAsSeparateTierAlongsideTitleResults() async {
        // The headline DUT-11 behavior through the VM: "ground beef" returns a
        // title match (Ground Beef Tacos) in `items` AND a recipe that merely
        // USES ground beef (Skillet Lasagna, id 7) in the labeled tier.
        let dependencies = FakeSearchDependencies()
        dependencies.results["ground beef"] = [Self.makeItem(1, title: "Ground Beef Tacos")]
        dependencies.localIngredientIDs["ground beef"] = [7]
        dependencies.cachedItemsByID[7] = Self.makeItem(7, title: "Skillet Lasagna")
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "ground beef"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .results)
        #expect(viewModel.items.map(\.id) == [1], "Title tier holds the title match")
        #expect(
            viewModel.ingredientItems.map(\.id) == [7],
            "Ingredient tier holds the recipe that uses the term but isn't a title match"
        )
    }

    @Test func ingredientTierExcludesRecipesAlreadyInTitleResults() async {
        // A recipe that matches BOTH by title and by ingredient appears ONLY
        // in the title tier — never duplicated into the ingredient tier.
        let dependencies = FakeSearchDependencies()
        dependencies.results["chili"] = [Self.makeItem(1, title: "Beef Chili")]
        dependencies.localIngredientIDs["chili"] = [1, 2]
        dependencies.cachedItemsByID[1] = Self.makeItem(1, title: "Beef Chili")
        dependencies.cachedItemsByID[2] = Self.makeItem(2, title: "Weeknight Cornbread")
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "chili"
        await viewModel.runImmediateSearch()
        #expect(viewModel.items.map(\.id) == [1])
        #expect(
            viewModel.ingredientItems.map(\.id) == [2],
            "Recipe 1 is a title hit, so it's deduped out of the ingredient tier"
        )
    }

    @Test func titleOnlyQueryLeavesIngredientTierEmpty() async {
        // No ingredient-index hits → the tier is empty and only title results
        // render. Guards against the section appearing spuriously.
        let dependencies = FakeSearchDependencies()
        dependencies.results["pasta"] = [Self.makeItem(1, title: "Pasta Bake")]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "pasta"
        await viewModel.runImmediateSearch()
        #expect(viewModel.items.count == 1)
        #expect(viewModel.ingredientItems.isEmpty)
    }

    @Test func ingredientOnlyHitWithNoTitleMatchStaysOnResults() async {
        // Online, REST returns nothing, but the ingredient index has a hit:
        // state must be `.results` (not `.noResults`) so the labeled section
        // renders.
        let dependencies = FakeSearchDependencies()
        dependencies.results["paprika"] = []
        dependencies.localIngredientIDs["paprika"] = [9]
        dependencies.cachedItemsByID[9] = Self.makeItem(9, title: "Goulash")
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "paprika"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .results)
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.ingredientItems.map(\.id) == [9])
    }

    @Test func offlineWithLocalIngredientHitsSurfacesIngredientTier() async {
        // DUT-11 reverses the CL-120 v1 deferral: the local ingredient index
        // works offline, so an offline query matching a cached recipe's
        // *ingredient list* (here "garlic" → recipe 42, title is NOT "garlic")
        // surfaces it in the ingredient tier instead of the hard `.offline`
        // screen. REST must not be called when offline.
        let dependencies = FakeSearchDependencies()
        dependencies.online = false
        dependencies.localIngredientIDs["garlic"] = [42]
        dependencies.cachedItemsByID[42] = Self.makeItem(42, title: "Weeknight Skillet")
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "garlic"
        await viewModel.runImmediateSearch()
        #expect(
            viewModel.state == .results,
            "An offline ingredient hit keeps the user on a results screen (DUT-11)"
        )
        #expect(viewModel.items.isEmpty, "No REST + no title match → empty title tier")
        #expect(viewModel.ingredientItems.map(\.id) == [42])
        #expect(dependencies.searches.isEmpty, "REST must not be called when offline")
    }

    @Test func offlineWithNoIngredientHitsStillGoesOffline() async {
        // The offline guard still fires when BOTH tiers are empty — DUT-11
        // only rescues the screen when there's an actual local hit.
        let dependencies = FakeSearchDependencies()
        dependencies.online = false
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "anything"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .offline)
        #expect(viewModel.ingredientItems.isEmpty)
    }

    @Test func clearWipesIngredientTier() async {
        let dependencies = FakeSearchDependencies()
        dependencies.localIngredientIDs["garlic"] = [3]
        dependencies.cachedItemsByID[3] = Self.makeItem(3, title: "Roast Chicken")
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "garlic"
        await viewModel.runImmediateSearch()
        #expect(!viewModel.ingredientItems.isEmpty)
        viewModel.clear()
        #expect(viewModel.ingredientItems.isEmpty, "clear() must reset the ingredient tier")
    }

    @Test func shrinkingQueryBelowMinLengthWipesIngredientTier() async {
        // Editing the query down to a single character resets the tier so a
        // stale section can't linger under the idle empty state.
        let dependencies = FakeSearchDependencies()
        dependencies.localIngredientIDs["garlic"] = [3]
        dependencies.cachedItemsByID[3] = Self.makeItem(3, title: "Roast Chicken")
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.debounceMilliseconds = 0
        viewModel.query = "garlic"
        await viewModel.runImmediateSearch()
        #expect(!viewModel.ingredientItems.isEmpty)
        // Backspace to one character — `scheduleSearch` short-circuits to idle.
        viewModel.query = "g"
        #expect(viewModel.state == .idle)
        #expect(viewModel.ingredientItems.isEmpty)
    }

    // MARK: - Helpers

    static func makeItem(_ id: Int, title: String = "Match") -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "\(title) \(id)",
            excerpt: "Excerpt",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }

    static func scratchRecents() -> RecentSearches {
        let suiteName = "dod.searchDUT11Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}
