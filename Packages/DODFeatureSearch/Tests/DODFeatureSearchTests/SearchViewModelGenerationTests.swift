import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

/// H1 (SDET 2026-06-28) — a slow earlier search must not overwrite a faster
/// later one. `performSearch()` stamps a monotonic `searchGeneration`; the
/// finalize hop (`finishTextSearch` → `applyFiltersAndFinalize`) and the lazy
/// hydration tasks bail if a newer search has bumped the generation since they
/// started. Reproduced white-box by driving the finalize hop with a stale token.
@MainActor
@Suite("SearchViewModel search-generation guard (H1)") struct SearchViewModelGenerationTests {

    @Test func staleFinalizeDoesNotOverwriteNewerResults() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["chicken"] = [Self.makeItem(1, title: "Chicken")]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()
        #expect(viewModel.items.map(\.id) == [1])
        let currentGeneration = viewModel.searchGeneration

        // A slow earlier "chick" search finally returns AFTER "chicken" won. Its
        // finalize carries a now-stale generation and must NOT clobber items.
        await viewModel.finishTextSearch(
            merged: [Self.makeItem(2, title: "Chicken Pot Pie")],
            localItems: [],
            trimmed: "chick",
            online: true,
            generation: currentGeneration - 1
        )
        #expect(viewModel.items.map(\.id) == [1])  // still chicken — stale finish bailed

        // The guard isn't over-eager: a finalize at the CURRENT generation applies.
        await viewModel.finishTextSearch(
            merged: [Self.makeItem(2, title: "Chicken Pot Pie")],
            localItems: [],
            trimmed: "chicken",
            online: true,
            generation: currentGeneration
        )
        #expect(viewModel.items.map(\.id) == [2])
    }

    /// DUT-221: tapping Clear (X) while a query is still in flight must not let
    /// that slow query repaint its results over the now-idle screen. `clear()`
    /// bumps the generation, so a finalize carrying the pre-clear token bails.
    @Test func clearMakesInFlightSearchBailInsteadOfRepainting() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["chicken"] = [Self.makeItem(1, title: "Chicken")]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()
        // A search is conceptually in flight at this generation.
        let inFlightGeneration = viewModel.searchGeneration

        // User taps Clear before the slow query returns.
        viewModel.clear()
        #expect(viewModel.state == .idle)
        #expect(viewModel.items.isEmpty)

        // The slow query now returns; its finalize must NOT repaint over idle.
        await viewModel.finishTextSearch(
            merged: [Self.makeItem(9, title: "Chicken Soup")],
            localItems: [],
            trimmed: "chicken",
            online: true,
            generation: inFlightGeneration
        )
        #expect(viewModel.state == .idle)
        #expect(viewModel.items.isEmpty)
    }

    /// DUT-568 Finding A: `computeDidYouMean` `await`s the cached-titles fetch
    /// AFTER the last generation check. A newer search that bumps the generation
    /// during that await must not have its banner clobbered by the older pass's
    /// suggestion. Reproduced with the `cachedTitlesGate` seam: the older
    /// continuation is held inside the fetch while the generation is bumped, then
    /// resumed — it must re-check `generation == searchGeneration` and bail.
    @Test func staleDidYouMeanDoesNotOverwriteNewerBanner() async {
        let dependencies = FakeSearchDependencies()
        dependencies.cachedTitlesArray = ["Cast Iron Skillet Nachos"]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        // A newer search has already set the banner and owns this generation.
        viewModel.didYouMean = "brisket"
        let newerGeneration = viewModel.searchGeneration

        // The older "naxxos" pass runs one generation behind and is held inside
        // the cached-titles fetch; while suspended, assert the newer banner is
        // still intact, then release it.
        let gate = SearchGate()
        dependencies.cachedTitlesGate = { await gate.wait() }

        let stalePass = Task { @MainActor in
            await viewModel.computeDidYouMean(
                itemCount: 1,
                trimmed: "naxxos",
                generation: newerGeneration - 1
            )
        }
        // Spin until the stale pass has parked inside the gated fetch.
        while await !gate.isWaiting { await Task.yield() }
        #expect(viewModel.didYouMean == "brisket", "Newer banner intact mid-await")
        await gate.release()
        await stalePass.value

        #expect(
            viewModel.didYouMean == "brisket",
            "Stale computeDidYouMean re-checks the generation and bails"
        )
    }

    /// DUT-568 Finding B: backspacing to a `< 2`-char query resets to idle and
    /// must clear `didYouMean` for parity with `clear()` (previously stranded).
    @Test func backspacingToShortQueryClearsDidYouMean() async {
        let dependencies = FakeSearchDependencies()
        dependencies.results["naxxos"] = [Self.makeItem(1, title: "Naxxos")]
        dependencies.cachedTitlesArray = ["Cast Iron Skillet Nachos"]
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        viewModel.query = "naxxos"
        await viewModel.runImmediateSearch()
        #expect(viewModel.didYouMean == "nachos", "Sparse result seeds the banner")

        // Backspace down to a single character → the short-query idle branch.
        viewModel.query = "n"
        #expect(viewModel.state == .idle, "Short query resets to idle")
        #expect(viewModel.didYouMean == nil, "Idle reset clears the rescue banner")
    }

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
        let suiteName = "dod.searchGenTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}

/// DUT-568: a one-shot async gate. A caller `await`s `wait()`, parking until
/// the test calls `release()`; `isWaiting` lets the test spin until the caller
/// has actually parked so the "newer search bumps generation mid-await" window
/// is deterministic rather than timing-dependent.
private actor SearchGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false
    private(set) var isWaiting = false

    func wait() async {
        if released { return }
        isWaiting = true
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}
