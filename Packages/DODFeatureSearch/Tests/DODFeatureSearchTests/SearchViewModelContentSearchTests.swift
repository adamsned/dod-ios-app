import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

/// v2 Search overhaul (2/3) — the headline behavior change: the WordPress
/// `?search=` endpoint searches recipe CONTENT (ingredients/method), and those
/// body-only hits USED to be discarded by the title-precision filter. They now
/// SURVIVE into the "Recipes Using <term>" tier (`ingredientItems`), ranked
/// beneath the title matches. This suite proves the survival + ranking + dedupe
/// contract at the view-model seam with a fake whose `search(query:)` returns a
/// mix of title-matching AND content-only recipes.
@MainActor
@Suite("SearchViewModel — v2 content/ingredient search")
struct SearchViewModelContentSearchTests {

    @Test func contentOnlyServerMatchesSurviveBelowTitleMatches() async {
        // "buttermilk" returns one title hit and two recipes that merely USE
        // buttermilk (title has no "buttermilk"). Pre-v2 the latter two were
        // dropped; now they surface in the "Recipes Using" tier, in WP order.
        let dependencies = FakeSearchDependencies()
        dependencies.results["buttermilk"] = [
            Self.makeItem(1, title: "Buttermilk Biscuits"),  // title match
            Self.makeItem(2, title: "Fried Chicken"),  // content-only (uses buttermilk)
            Self.makeItem(3, title: "Ranch Dressing"),  // content-only
        ]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        viewModel.query = "buttermilk"
        await viewModel.runImmediateSearch()

        #expect(viewModel.state == .results)
        #expect(
            viewModel.items.map(\.id) == [1],
            "Title matches rank ahead — only the title hit is in the primary tier"
        )
        #expect(
            viewModel.ingredientItems.map(\.id) == [2, 3],
            "Content-only server matches must SURVIVE (not be filtered out), in WP relevance order"
        )
    }

    @Test func ingredientQueryReturnsCatalogWideRecipesThatUseIt() async {
        // The required outcome: searching an ingredient returns the recipes
        // that use it, even when NONE of them name it in the title.
        let dependencies = FakeSearchDependencies()
        dependencies.results["ground beef"] = [
            Self.makeItem(10, title: "Turkey Chili"),
            Self.makeItem(11, title: "Sweet Potato Hash"),
            Self.makeItem(12, title: "Philly Cheesesteak Pasta"),
        ]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        viewModel.query = "ground beef"
        await viewModel.runImmediateSearch()

        #expect(viewModel.state == .results, "Content matches keep us on a results screen")
        #expect(viewModel.items.isEmpty, "No title names 'ground beef' — primary tier is empty")
        #expect(
            viewModel.ingredientItems.map(\.id) == [10, 11, 12],
            "All three catalog-wide content matches survive — the pre-v2 discard is gone"
        )
    }

    @Test func contentMatchNeverDuplicatesATitleMatch() async {
        // A recipe returned once that BOTH title-matches stays in the title
        // tier and does not also appear in the "Recipes Using" tier.
        let dependencies = FakeSearchDependencies()
        dependencies.results["chili"] = [
            Self.makeItem(1, title: "Beef Chili"),  // title match
            Self.makeItem(2, title: "Cornbread"),  // content-only
        ]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        viewModel.query = "chili"
        await viewModel.runImmediateSearch()

        #expect(viewModel.items.map(\.id) == [1])
        #expect(viewModel.ingredientItems.map(\.id) == [2])
        let allShownIDs = viewModel.items.map(\.id) + viewModel.ingredientItems.map(\.id)
        #expect(Set(allShownIDs).count == allShownIDs.count, "No recipe card is shown twice")
    }

    @Test func localIngredientIndexSupplementsAndDedupesAgainstServerContent() async {
        // The local ingredient index stays as an offline supplement: it adds
        // rows the server pass DIDN'T return, deduped against the server
        // content matches (which lead because they're catalog-wide).
        let dependencies = FakeSearchDependencies()
        dependencies.results["ground beef"] = [
            Self.makeItem(1, title: "Ground Beef Tacos"),  // title match
            Self.makeItem(2, title: "Turkey Chili"),  // server content-only
        ]
        // Local index knows recipe 2 (already covered by server) + recipe 3 (new).
        dependencies.localIngredientIDs["ground beef"] = [2, 3]
        dependencies.cachedItemsByID[2] = Self.makeItem(2, title: "Turkey Chili")
        dependencies.cachedItemsByID[3] = Self.makeItem(3, title: "Sloppy Joes")
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        viewModel.query = "ground beef"
        await viewModel.runImmediateSearch()

        #expect(viewModel.items.map(\.id) == [1])
        #expect(
            viewModel.ingredientItems.map(\.id) == [2, 3],
            "Server content first (id 2), then the local-only supplement (id 3) — id 2 not duplicated"
        )
    }

    // MARK: - Helpers

    static func makeItem(_ id: Int, title: String) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: title,
            excerpt: "Excerpt",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }

    static func scratchRecents() -> RecentSearches {
        let suiteName = "dod.searchContentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}
