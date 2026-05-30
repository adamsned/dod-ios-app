import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

/// CL-106 (T-637) — three Search-page bug fixes pinned by L1 tests.
/// Split into a separate file so `SearchViewModelTests.swift` stays under
/// SwiftLint's `file_length` cap.
///
/// - chip-row gating: viewmodel `state` transitions correctly so the
///   `state != .idle` `@ViewBuilder` gate in `SearchView` flips visibility
/// - cook-time hydration: `fetchTotalSeconds(...)` fires when the filter
///   is active and the cache is missing entries; result set narrows
///   after hydration lands
/// - "Latest Recipes" Try-pill: `surfaceLatestRecipes(...)` fetches the
///   N most-recent posts via `fetchLatestRecipes(...)` instead of running
///   a literal text search; does NOT persist a recent or send telemetry
@MainActor
@Suite("SearchViewModel CL-106 / T-637") struct SearchViewModelT637Tests {

    /// US-12 / AC-12.2 amendment / CL-106 (T-637): the FilterChipRow view
    /// is gated on `state != .idle`. The viewmodel-side contract this
    /// test pins is that the viewmodel transitions to a non-idle state
    /// the moment a real search is in flight or has produced results,
    /// and stays at `.idle` before any search is initiated.
    @Test func chipRowGatingByStateTransitionsAwayFromIdleOnSearch() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["pizza"] = [Self.makeItem(1)]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        #expect(viewModel.state == .idle)
        viewModel.query = "pizza"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .results)
        viewModel.clear()
        #expect(viewModel.state == .idle)
    }

    /// US-12 / AC-12.3 amendment / CL-106 (T-637): when the cook-time
    /// filter is active and some result items lack a known total time,
    /// the viewmodel fires a network-side `fetchTotalSeconds(...)` call,
    /// merges the hydrated values into `lastTotalSecondsByRecipe`, and
    /// re-applies the filter so the result set narrows correctly.
    @Test func cookTimeFilterHydratesUncachedItemsAndNarrows() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["chili"] = [
            Self.makeItem(1, title: "Quick Chili"),
            Self.makeItem(2, title: "Slow Chili"),
            Self.makeItem(3, title: "Mystery Chili"),
        ]
        dependencies.networkTotalSecondsMap = [
            1: 20 * 60,
            2: 45 * 60,
        ]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.filters.cookTime = .under30
        viewModel.query = "chili"
        await viewModel.runImmediateSearch()
        // Immediately after the search, the cache is empty so the
        // filter rejects every item — the bug T-637 fixes.
        #expect(viewModel.items.isEmpty)
        // Poll for the fire-and-forget hydration task + reapplyFilters(). A
        // fixed 40ms sleep raced on CI's slower runners; poll up to ~2s and
        // return as soon as hydration narrows the set.
        for _ in 0..<200 where viewModel.items.map(\.id) != [1] {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(
            viewModel.items.map(\.id) == [1],
            "After hydration: only item 1 fits the under-30 bucket"
        )
        #expect(
            !dependencies.networkTotalSecondsCalls.isEmpty,
            "Hydration must call fetchTotalSeconds(...)"
        )
    }

    /// US-29 / AC-29.1 amendment / CL-106 (T-637): tapping the "Latest
    /// Recipes" Try-pill fetches the N most-recent posts via
    /// `fetchLatestRecipes(...)` instead of running a literal text search.
    /// Path does NOT persist a recent and does NOT send telemetry.
    @Test func surfaceLatestRecipesFetchesRecentPostsAndSkipsRecents() async {
        let scratch = Self.scratchRecents()
        let dependencies = FakeSearchDependencies()
        dependencies.latestRecipes = (101...108).map {
            Self.makeItem($0, title: "Newest")
        }
        let viewModel = SearchViewModel(dependencies: dependencies, recentSearches: scratch)

        await viewModel.surfaceLatestRecipes()

        #expect(viewModel.items.count == 5, "Default limit=5 trims after over-fetch")
        #expect(viewModel.items.map(\.id) == [101, 102, 103, 104, 105])
        #expect(viewModel.state == .results)
        #expect(
            dependencies.latestRecipesCalls.first == 8,
            "Over-fetch ceil(5 * 1.5) = 8"
        )
        #expect(viewModel.recentSearches.isEmpty)
        #expect(scratch.recent().isEmpty)
        #expect(dependencies.searches.isEmpty)
        #expect(dependencies.searchHashes.isEmpty)
    }

    /// CL-106 (T-637): the Latest-Recipes surface flag means a filter
    /// mutation re-applies against the latest-recipes set rather than
    /// running `reapplyFilters()` against the empty `lastQuery`.
    @Test func filterMutationAfterLatestRecipesReAppliesAgainstLatestSet() async {
        let dependencies = FakeSearchDependencies()
        dependencies.latestRecipes = [
            Self.makeItem(201, title: "Quick"),
            Self.makeItem(202, title: "Slow"),
        ]
        dependencies.totalSecondsMap = [
            201: 10 * 60,
            202: 45 * 60,
        ]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        await viewModel.surfaceLatestRecipes(limit: 2)
        #expect(viewModel.items.count == 2)

        viewModel.filters.cookTime = .under30
        #expect(viewModel.items.map(\.id) == [201])
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
        let suiteName = "dod.searchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}
