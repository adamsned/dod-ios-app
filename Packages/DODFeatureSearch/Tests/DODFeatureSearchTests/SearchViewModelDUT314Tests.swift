import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

/// DUT-314 — perf gate for `applyFiltersAndFinalize`. The three filter-support
/// fetches (`categoryIDs`, `totalSeconds`, `recentlyViewedRecipeIDs`) feed maps
/// that `SearchFilters.apply` ignores entirely when `filters.isAllDefault`, so
/// they must be skipped on the common no-filter search and only fire once a
/// filter is active. These tests pin that gating via the fetch counters on
/// `FakeSearchDependencies` — the result set itself is unchanged either way
/// (the fix is behaviour-preserving, perf-only).
@MainActor
@Suite("SearchViewModel DUT-314") struct SearchViewModelDUT314Tests {

    @Test func defaultFiltersSkipFilterSupportFetches() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["Stew"] = [
            Self.makeItem(1, title: "Beef Stew"),
            Self.makeItem(2, title: "Lamb Stew"),
        ]

        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        viewModel.query = "Stew"
        await viewModel.runImmediateSearch()

        // Results land exactly as before — gating is invisible to the user.
        #expect(viewModel.state == .results)
        #expect(viewModel.items.count == 2)

        // None of the three filter-support fetches fired on the default path.
        #expect(dependencies.categoryIDsCalls.isEmpty)
        #expect(dependencies.totalSecondsCalls.isEmpty)
        #expect(dependencies.recentlyViewedCallCount == 0)

        // And the caches were left empty (apply ignores them anyway).
        #expect(viewModel.lastCategoryIDsByRecipe.isEmpty)
        #expect(viewModel.lastTotalSecondsByRecipe.isEmpty)
        #expect(viewModel.lastRecentlyViewedIDs.isEmpty)
    }

    @Test func activeFilterStillRunsFilterSupportFetches() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["Stew"] = [
            Self.makeItem(1, title: "Beef Stew"),
            Self.makeItem(2, title: "Lamb Stew"),
        ]
        // Seed the cook-time map so the active filter narrows to one item.
        dependencies.totalSecondsMap = [1: 20 * 60, 2: 90 * 60]

        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        // A non-default filter must un-gate the fetches.
        viewModel.filters.cookTimeMaxSeconds = 30 * 60

        viewModel.query = "Stew"
        await viewModel.runImmediateSearch()

        // The active filter un-gates the fetches: because the cook-time filter
        // is set BEFORE the search runs, `applyFiltersAndFinalize` takes the
        // non-default branch and hydrates the support maps inline.
        #expect(!dependencies.categoryIDsCalls.isEmpty)
        #expect(!dependencies.totalSecondsCalls.isEmpty)
        #expect(dependencies.recentlyViewedCallCount >= 1)

        // And the filter actually narrowed using the hydrated map.
        #expect(viewModel.items.map(\.id) == [1])
    }

    @Test func chipToggleAfterDefaultSearchLazilyHydratesAndNarrows() async {
        // The search runs with default filters (fetches skipped), THEN the
        // user taps a category chip. The skipped support map must be lazily
        // hydrated so the re-rank still narrows correctly — preserving the
        // US-12 / AC-12.3 "filter chip re-ranks the cached set" contract.
        let dependencies = FakeSearchDependencies()
        dependencies.results["soup"] = [
            Self.makeItem(1, title: "Beef Soup"),
            Self.makeItem(2, title: "Chicken Soup"),
        ]
        dependencies.categoryMap = [1: [10], 2: [20]]

        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "soup"
        await viewModel.runImmediateSearch()

        // Default search: support fetch skipped.
        #expect(dependencies.categoryIDsCalls.isEmpty)
        #expect(viewModel.items.count == 2)

        // Toggle a category chip — lazy hydration fires a fire-and-forget Task.
        viewModel.filters.categoryID = 10
        for _ in 0..<200 where viewModel.items.map(\.id) != [1] {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(viewModel.items.map(\.id) == [1])
        #expect(!dependencies.categoryIDsCalls.isEmpty, "Toggle must lazily hydrate the support map")

        // A second toggle stays fully in-memory — no further support fetch.
        let callsAfterFirstToggle = dependencies.categoryIDsCalls.count
        viewModel.filters.categoryID = 20
        for _ in 0..<200 where viewModel.items.map(\.id) != [2] {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(viewModel.items.map(\.id) == [2])
        #expect(
            dependencies.categoryIDsCalls.count == callsAfterFirstToggle,
            "Subsequent toggles must re-rank in-memory with no extra fetch"
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

    /// Per-test isolated UserDefaults so the disk-backed history doesn't
    /// leak between tests on the same machine. Mirrors the helper in the
    /// other suites so this file is self-contained.
    static func scratchRecents() -> RecentSearches {
        let suiteName = "dod.searchDUT314Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}
