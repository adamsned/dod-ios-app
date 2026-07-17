import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureSearch

/// Concurrency-hunt finding: `reapplyFilters()` launches TWO independent
/// detached `Task`s back to back whenever the user's first cook-time-filter
/// toggle follows a default (`isAllDefault`) search — `kickOffFilterSupport-
/// HydrationIfNeeded(against:)` (DUT-314's lazy filter-support hydration) and
/// `kickOffCookTimeHydrationIfNeeded(against:)` (the cook-time-specific
/// network hydration). Both write into the SAME `lastTotalSecondsByRecipe`
/// dictionary with no serialization between them.
///
/// Before the fix, DUT-314's completion did a DESTRUCTIVE full-dictionary
/// replace (`self.lastTotalSecondsByRecipe = totalSeconds`) instead of a
/// per-key merge. If the cook-time Task (no gate, resolves fast off a single
/// network fetch) lands FIRST and merges in the correct total-seconds entry
/// for a recipe, DUT-314's Task — gated here to resolve SECOND off its own
/// stale/empty cache-only fetch — used to WIPE OUT that entry, silently
/// dropping the recipe back out of the cook-time-filtered result set even
/// though its cook time IS known and in-range. The fix makes DUT-314's
/// completion merge key-by-key too (mirroring the cook-time Task's own
/// idiom), so neither Task can erase the other's contribution regardless of
/// completion order.
@MainActor
@Suite("SearchViewModel filter-support / cook-time hydration race")
struct SearchViewModelFilterHydrationRaceTests {

    @Test func cookTimeHydrationEntrySurvivesConcurrentFilterSupportHydration() async {
        let dependencies = FakeSearchDependencies()
        let item = RecipeListItem(
            id: 1,
            title: "Chicken",
            excerpt: "e",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
        dependencies.results["chicken"] = [item]
        // Only the cook-time-hydration path (the network fetch) can discover
        // this recipe's total time — the cache-only `totalSecondsMap` is
        // deliberately left empty so DUT-314's fetch returns nothing for id 1.
        dependencies.networkTotalSecondsMap[1] = 900

        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: Self.scratchRecents()
        )

        // Default-filters search: finds the recipe via REST, no cook-time
        // gate applied yet, and (per DUT-314) skips the inline filter-support
        // fetches since `filters.isAllDefault` — leaving `lastTotalSecondsByRecipe`
        // empty and `filterSupportHydrated == false`.
        viewModel.query = "chicken"
        await viewModel.runImmediateSearch()
        #expect(viewModel.items.map(\.id) == [1], "Initial default-filter search finds the recipe")

        // Park DUT-314's cache-only `totalSeconds(forRecipeIDs:)` fetch in flight
        // so its completion (the destructive-replace-turned-merge) resolves
        // AFTER the cook-time Task below.
        let gate = FilterHydrationGate()
        dependencies.totalSecondsGate = { await gate.wait() }

        // The user's first cook-time filter toggle. This synchronously fires
        // `reapplyFilters()` inside `filters`'s `didSet`, which launches BOTH
        // `kickOffFilterSupportHydrationIfNeeded` (parks on the gate above)
        // AND `kickOffCookTimeHydrationIfNeeded` (no gate, resolves fast off
        // `networkTotalSecondsMap`) before this line returns.
        viewModel.filters.cookTimeMinSeconds = 600

        // Deterministically wait until DUT-314's Task has parked inside the
        // gated fetch — proves the race window is open, not timing-dependent.
        while await !gate.isWaiting {
            await Task.yield()
        }

        // The cook-time Task has no gate, so by the time DUT-314 has parked,
        // it has very likely already merged `[1: 900]` in and re-applied the
        // filter. Spin until that lands.
        while viewModel.items.isEmpty {
            await Task.yield()
        }
        #expect(
            viewModel.items.map(\.id) == [1],
            "Cook-time hydration Task correctly surfaced the recipe (900s is within the 600s+ range)"
        )

        // Release DUT-314's gate so its Task resumes and commits its write.
        // Spin on the `recentlyViewedRecipeIDs()` call count — DUT-314's Task
        // calls it as the LAST await before its (synchronous, no-further-
        // suspension) write + `reapplyFilters()` tail, so once that call
        // count ticks up, the write is guaranteed to have completed by the
        // next time this test (itself MainActor-isolated, so it can't
        // interleave mid-tail) gets a turn.
        await gate.release()
        let recentlyViewedCallsBeforeRelease = dependencies.recentlyViewedCallCount
        var spins = 0
        while dependencies.recentlyViewedCallCount == recentlyViewedCallsBeforeRelease, spins < 1000 {
            await Task.yield()
            spins += 1
        }
        // A further handful of round-trips lets a self-healing re-fetch (the
        // bug's symptom below) run to completion too, so both code paths
        // reach a fully settled state before the assertions.
        for _ in 0..<20 {
            await Task.yield()
        }

        // The regression this test catches: DUT-314's later-landing,
        // cache-only (empty) fetch must NOT clobber the cook-time Task's
        // already-merged entry for id 1. `reapplyFilters()` re-invokes
        // `kickOffCookTimeHydrationIfNeeded` on every call (including the one
        // DUT-314's own completion triggers), so a destructive overwrite is
        // self-healing — the SAME recipe gets a SECOND redundant network
        // fetch and the result eventually re-converges to correct. That
        // self-heal masks the bug from a naive "is the final state correct?"
        // check, so the real regression signal is the redundant fetch count:
        // exactly ONE network cook-time fetch should ever be needed for this
        // recipe. Before the fix this is 2 (the clobber forces a second,
        // wasteful round-trip and a transient flicker back to `.noResults`
        // in between); after the fix it stays 1.
        #expect(
            dependencies.networkTotalSecondsCalls.count == 1,
            "DUT-314's later-landing cache-only fetch must not force a redundant cook-time re-fetch"
        )
        #expect(
            viewModel.items.map(\.id) == [1],
            "Final state must show the recipe (this alone doesn't catch the bug — the self-heal above does)"
        )
    }

    static func scratchRecents() -> RecentSearches {
        let suiteName = "dod.filterHydrationRaceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return RecentSearches(defaults: defaults, storageKey: "recents")
    }
}

/// A one-shot async gate. A caller `await`s `wait()`, parking until the test
/// calls `release()`; `isWaiting` lets the test spin until the caller has
/// actually parked so the race window is deterministic rather than
/// timing-dependent. Named distinctly from `SearchGate` (declared privately
/// in `SearchViewModelGenerationTests.swift`) to avoid a same-module redeclaration
/// clash.
private actor FilterHydrationGate {
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
