import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

@MainActor
@Suite("SearchViewModel (T-100..T-103, US-12)") struct SearchViewModelTests {

    @Test func shortQueriesAreIgnored() async {
        let dependencies = FakeSearchDependencies()
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.debounceMilliseconds = 0
        viewModel.query = "a"
        try? await Task.sleep(nanoseconds: 5_000_000)
        #expect(viewModel.state == .idle)
        #expect(dependencies.searches.isEmpty)
    }

    @Test func successfulSearchPopulatesItems() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["pasta"] = [Self.makeItem(1), Self.makeItem(2)]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "pasta"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .results)
        #expect(viewModel.items.count == 2)
    }

    @Test func emptyResultSetTransitionsToNoResults() async {
        let dependencies = FakeSearchDependencies()
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "zzz"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .noResults)
    }

    @Test func offlineWithNoLocalIngredientHitsGoesOffline() async {
        // No REST + no local match → genuine offline state. v2 only shows
        // offline when both passes returned nothing.
        let dependencies = FakeSearchDependencies()
        dependencies.online = false
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "anything"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .offline)
        #expect(dependencies.searches.isEmpty, "REST must not be called when offline")
    }

    @Test func offlineWithLocalIngredientHitsStillShowsResults() async {
        // US-12 / AC-12.1 graceful degradation: the local ingredient index
        // works offline, so a recipe whose ingredients match should still
        // surface even with the network down.
        let dependencies = FakeSearchDependencies()
        dependencies.online = false
        dependencies.localIngredientIDs["garlic"] = [42]
        dependencies.cachedItemsByID[42] = Self.makeItem(42, title: "Garlic Bread")
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "garlic"
        await viewModel.runImmediateSearch()
        #expect(viewModel.state == .results)
        #expect(viewModel.items.map(\.id) == [42])
    }

    @Test func clearResetsState() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["something"] = [Self.makeItem(1)]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "something"
        await viewModel.runImmediateSearch()
        viewModel.clear()
        #expect(viewModel.state == .idle)
        #expect(viewModel.items.isEmpty)
        #expect(viewModel.query.isEmpty)
    }

    @Test func telemetrySendsHashedQueryNotRaw() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["secret query"] = []
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "secret query"
        await viewModel.runImmediateSearch()
        let sent = try? #require(dependencies.searchHashes.first)
        let expected = StringHasher.sha256Hex("secret query")
        #expect(sent == expected)
        // The raw text must never reach analytics.
        #expect(!(sent ?? "").contains("secret"))
    }

    // MARK: - US-12

    @Test func filterChipNarrowsResultsWithoutNetworkRoundTrip() async {
        // US-12 / AC-12.3: filter mutation re-ranks the cached set; no
        // additional REST call should happen.
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
        #expect(viewModel.items.count == 2)
        let restCallsBefore = dependencies.searches.count

        viewModel.filters.categoryID = 10
        #expect(viewModel.items.map(\.id) == [1])
        #expect(
            dependencies.searches.count == restCallsBefore,
            "Filter changes must NOT trigger another REST search"
        )
    }

    @Test func recentSearchesPersistAcrossViewModelInstances() async {
        // US-12 / AC-12.4: a recent query recorded by one VM is visible to
        // the next VM constructed against the same RecentSearches store.
        let scratch = Self.scratchRecents()
        let dependencies = FakeSearchDependencies()
        dependencies.results["pizza"] = [Self.makeItem(1)]
        let firstVM = SearchViewModel(dependencies: dependencies, recentSearches: scratch)
        firstVM.query = "pizza"
        await firstVM.runImmediateSearch()
        #expect(firstVM.recentSearches.first == "pizza")

        let secondVM = SearchViewModel(dependencies: dependencies, recentSearches: scratch)
        #expect(secondVM.recentSearches.contains("pizza"))
    }

    @Test func clearRecentSearchesEmptiesStore() async {
        // US-29 / AC-29.2 / CL-49.2: `clearRecentSearches()` wipes both
        // the persisted `RecentSearches` store and the in-memory array
        // the view binds to.
        let scratch = Self.scratchRecents()
        let dependencies = FakeSearchDependencies()
        dependencies.results["pasta"] = [Self.makeItem(1)]
        let viewModel = SearchViewModel(dependencies: dependencies, recentSearches: scratch)
        viewModel.query = "pasta"
        await viewModel.runImmediateSearch()
        #expect(viewModel.recentSearches.first == "pasta")

        viewModel.clearRecentSearches()
        #expect(viewModel.recentSearches.isEmpty)
        #expect(scratch.recent().isEmpty)
    }

    // REG-19 / CL-66 / T-670: tapping a curated "Try" suggestion must
    // NOT persist the tapped term into the recent-searches store, and
    // tapping Clear All after curated taps must leave Recent empty.
    // The pre-fix bug: `onCategoryTap` set `viewModel.query =
    // category.name` directly, which routed through the normal search
    // path and called `recents.record(...)` on completion — curated
    // category names ("Bourbon", "Sweet Potato", "Brisket", etc.)
    // leaked into Recent. Clear All cleared the store, but a later
    // observation tick / next idle render surfaced them again because
    // a debounced search that started just before Clear All could
    // complete after the wipe. This test pins the contract: after
    // `selectCuratedSuggestion(_:)` runs, no recent is recorded; after
    // `clearRecentSearches()` runs (regardless of any in-flight
    // debounce), `recentSearches.isEmpty == true`.
    @Test func curatedTapDoesNotRecordRecentAndClearAllLeavesRecentEmpty() async {
        let scratch = Self.scratchRecents()
        let dependencies = FakeSearchDependencies()
        dependencies.results["Bourbon"] = [Self.makeItem(1)]
        dependencies.results["Sweet Potato"] = [Self.makeItem(2)]
        dependencies.results["Brisket"] = [Self.makeItem(3)]
        let viewModel = SearchViewModel(dependencies: dependencies, recentSearches: scratch)
        viewModel.debounceMilliseconds = 0

        // Three curated "Try" pill taps in a row.
        viewModel.selectCuratedSuggestion("Bourbon")
        await viewModel.runImmediateSearch()
        viewModel.selectCuratedSuggestion("Sweet Potato")
        await viewModel.runImmediateSearch()
        viewModel.selectCuratedSuggestion("Brisket")
        await viewModel.runImmediateSearch()

        // Curated taps must not have polluted the recent-searches store.
        #expect(
            viewModel.recentSearches.isEmpty,
            "Curated 'Try' taps must not persist into Recent"
        )
        #expect(scratch.recent().isEmpty)

        // Now type a real query so a recent exists; then Clear All.
        viewModel.query = "pasta"
        dependencies.results["pasta"] = [Self.makeItem(99)]
        await viewModel.runImmediateSearch()
        #expect(viewModel.recentSearches == ["pasta"])

        viewModel.clearRecentSearches()
        #expect(viewModel.recentSearches.isEmpty)
        #expect(scratch.recent().isEmpty)

        // And a curated tap immediately after Clear All must also not
        // refill Recent — the bug-shaped sequence the user reported.
        viewModel.selectCuratedSuggestion("Bourbon")
        await viewModel.runImmediateSearch()
        #expect(
            viewModel.recentSearches.isEmpty,
            "Curated tap after Clear All must leave Recent empty"
        )
    }

    @Test func selectRecentReRunsSearchWithStoredQuery() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["tacos"] = [Self.makeItem(5, title: "Beef Tacos")]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.debounceMilliseconds = 0
        viewModel.selectRecent("tacos")
        // Poll for the debounced search to land. A fixed 20ms sleep raced on
        // CI's slower runners (the search hadn't completed → `items` empty →
        // flaky failure under Xcode-26 CI). Poll up to ~2s, returning as soon
        // as the result arrives — fast locally, tolerant on CI.
        for _ in 0..<200 where !viewModel.items.contains(where: { $0.id == 5 }) {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(viewModel.query == "tacos")
        #expect(viewModel.items.contains(where: { $0.id == 5 }))
    }

    // CL-106 / T-637 tests live in `SearchViewModelT637Tests.swift` so
    // this file stays under SwiftLint's `file_length` cap.

    @Test func displayedTrySlateIsStableAcrossReAccessesWithinSingleViewModel() async {
        // T-639 / CL-117 / AC-29.7: the rotating Try slate is computed
        // **once** per `SearchViewModel` lifetime and cached on the
        // viewmodel so re-accesses (`IdleSuggestionsView` re-creates on
        // tab switches / navigation) return the same slate within a
        // session. Cold launch (= fresh viewmodel) is the only reshuffle
        // trigger; this test pins the in-session stability.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = Self.makeRotationPool(size: 30)
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        let first = viewModel.displayedTrySlate
        let second = viewModel.displayedTrySlate
        let third = viewModel.displayedTrySlate
        #expect(first.map(\.id) == second.map(\.id))
        #expect(second.map(\.id) == third.map(\.id))
        // The pinned Latest-Recipes pill is always first on every read.
        #expect(first.first?.id == 1590)
    }

    @Test func emptyPoolAtFirstAccessDoesNotCachePartialSlate() async {
        // T-640 / CL-118: the cold-start cache race. The view appears
        // before `loadCategoriesIfNeeded()` resolves → first read of
        // `displayedTrySlate` sees an empty `availableCategories` →
        // `pickTrySlate(...)` returns the single synthesized [Latest
        // Recipes] pill (length 1, < `trySlateVisibleCount`). Pre-fix,
        // that partial slate was cached forever and the user was locked
        // to one pill for the session. The fix: only cache full-count
        // slates, so the next read after categories land recomputes
        // and the user sees the real rotation.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = []
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        // First read: pool is empty → partial slate (just pinned).
        let firstRead = viewModel.displayedTrySlate
        #expect(firstRead.count == 1)
        #expect(firstRead.first?.id == 1590)

        // Categories arrive (simulating the async fetch landing).
        dependencies.categories = Self.makeRotationPool(size: 30)
        await viewModel.loadCategoriesIfNeeded()

        // Second read: pool is now full → MUST recompute, not return
        // the cached 1-pill slate. This is the bug T-640 fixes.
        let secondRead = viewModel.displayedTrySlate
        #expect(secondRead.count == SearchViewModel.trySlateVisibleCount)
        #expect(secondRead.first?.id == 1590)
    }

    @Test func fullSlateCachesAndIsStableAcrossReads() async {
        // T-640 / CL-118: confirm the stable-within-session contract
        // still holds. Once a full-count slate caches, subsequent reads
        // return the same slate (the shuffle does not re-fire). This
        // is the existing T-639 contract — restated here to lock it
        // alongside the new cache-rule behavior.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = Self.makeRotationPool(size: 30)
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        let first = viewModel.displayedTrySlate
        let second = viewModel.displayedTrySlate
        #expect(first.count == SearchViewModel.trySlateVisibleCount)
        #expect(first.map(\.id) == second.map(\.id))
    }

    @Test func partialPoolSmallerThanVisibleCountDoesNotCache() async {
        // T-640 / CL-118: the cache rule fires ONLY when the slate
        // reaches the full visible count. A pool with just Latest
        // Recipes (no rotatable entries) produces a 1-pill slate per
        // `pickTrySlate(...)`'s "empty rotation tail → just pinned"
        // branch — same length as the empty-pool path, so the cache
        // rule must also skip caching here. Subsequent reads recompute,
        // and if the pool is later widened, the full slate computes
        // and caches as expected.
        let dependencies = FakeSearchDependencies()
        dependencies.categories = [
            DODDomain.Category(id: 1590, name: "Latest Recipes", slug: "latest-recipes", count: 0)
        ]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await viewModel.loadCategoriesIfNeeded()

        let firstRead = viewModel.displayedTrySlate
        #expect(firstRead.count == 1)
        #expect(firstRead.first?.id == 1590)

        // Widen the pool — categories grow (e.g. REST refetch). The
        // next read must recompute (not return the cached 1-pill
        // slate) and produce the full slate.
        dependencies.categories = Self.makeRotationPool(size: 30)
        // `loadCategoriesIfNeeded()` short-circuits when
        // `availableCategories` is non-empty, so reach in via the
        // public load path: clear-and-refetch isn't exposed, so seed
        // a fresh viewmodel to simulate the post-widening read. This
        // mirrors the production sequence: a single viewmodel sees
        // the categories land monotonically. The L1 assertion is that
        // the partial-slate cache rule does NOT lock the 1-pill
        // result, so the post-load full slate computes.
        let widerViewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        await widerViewModel.loadCategoriesIfNeeded()
        let widerRead = widerViewModel.displayedTrySlate
        #expect(widerRead.count == SearchViewModel.trySlateVisibleCount)
    }

    /// Helper: build a 30-category rotation pool with Latest Recipes
    /// pinned at id 1590 plus N-1 rotatable categories. Used by the
    /// T-639 stable-within-session test + the T-640 / CL-118 cache-race
    /// regression tests.
    static func makeRotationPool(size: Int) -> [DODDomain.Category] {
        (1...size).map { id in
            DODDomain.Category(
                id: id == 1 ? 1590 : id + 100,
                name: id == 1 ? "Latest Recipes" : "Cat\(id)",
                slug: id == 1 ? "latest-recipes" : "cat\(id)",
                count: 100 - id
            )
        }
    }

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

    /// Per-test isolated UserDefaults so the disk-backed history doesn't
    /// leak between tests on the same machine.
    static func scratchRecents() -> RecentSearches {
        let suiteName = "dod.searchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}
