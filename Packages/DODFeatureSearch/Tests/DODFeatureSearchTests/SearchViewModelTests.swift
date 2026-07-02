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
        // Titles must contain the query (post-CL-120 / T-642 title-precision
        // filter); the pre-T-642 `Self.makeItem(_:)` default title was
        // "Match N" which body-matched nothing and now correctly drops.
        let dependencies = FakeSearchDependencies()
        dependencies.results["pasta"] = [
            Self.makeItem(1, title: "Pasta"),
            Self.makeItem(2, title: "Pasta"),
        ]
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
        // DUT-254: `recipe_searched` now fires from the FINALIZED-search path
        // (`sendSearchTelemetry`, driven by `commitRecentSearch`), not from each
        // debounced pass — so exercise that method directly here.
        await viewModel.sendSearchTelemetry(trimmed: "secret query")
        let sent = try? #require(dependencies.searchHashes.first)
        let expected = StringHasher.sha256Hex("secret query")
        #expect(sent == expected)
        // The raw text must never reach analytics.
        #expect(!(sent ?? "").contains("secret"))
    }

    /// DUT-254: a live (debounced) search must NOT emit `recipe_searched`; only
    /// a finalized commit does. Prevents the per-keystroke inflation.
    @Test func debouncedSearchDoesNotEmitTelemetry() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["chicken"] = []
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )
        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()
        #expect(dependencies.searchHashes.isEmpty)
        // Finalizing the search (Return / keyboard dismissal) emits exactly one.
        viewModel.commitRecentSearch()
        for _ in 0..<20 where dependencies.searchHashes.isEmpty { await Task.yield() }
        #expect(dependencies.searchHashes.count == 1)

        // DUT-435: Return fires BOTH `.onSubmit` and the focus-loss commit —
        // the immediate second commit for the same query must NOT emit again.
        viewModel.commitRecentSearch()
        for _ in 0..<20 { await Task.yield() }
        #expect(dependencies.searchHashes.count == 1)

        // A re-typed (mutated) query commits — and counts — again.
        viewModel.query = "chicken pie"
        dependencies.results["chicken pie"] = []
        await viewModel.runImmediateSearch()
        viewModel.commitRecentSearch()
        for _ in 0..<20 where dependencies.searchHashes.count < 2 { await Task.yield() }
        #expect(dependencies.searchHashes.count == 2)
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
        // DUT-314: the search ran with default filters, so the category-id
        // support map was skipped. The first chip toggle lazily hydrates it
        // (a fire-and-forget Task) and re-ranks when it lands — poll for that,
        // mirroring the cook-time hydration test's pattern. This reads the
        // local persistence cache, NOT a REST search (asserted below).
        for _ in 0..<200 where viewModel.items.map(\.id) != [1] {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
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
        // T-779 / DUT-85: recents now record on commit (Return / dismissal), not the live search.
        firstVM.commitRecentSearch()
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
        viewModel.commitRecentSearch()  // T-779 / DUT-85: commit records the recent.
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
        viewModel.commitRecentSearch()  // T-779 / DUT-85: a real typed query records on commit.
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
        dependencies.categories = (1...10).map { id in
            DODDomain.Category(
                id: id == 1 ? 1590 : id + 100,
                name: id == 1 ? "Latest Recipes" : "Cat\(id)",
                slug: id == 1 ? "latest-recipes" : "cat\(id)",
                count: 100 - id
            )
        }
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
