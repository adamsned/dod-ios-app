import DODDomain
import DODSupport
import Foundation

/// v2 Search overhaul (2/3) — the debounce + primary-fetch pipeline
/// (`scheduleSearch` / `performSearch`), split out of `SearchViewModel.swift`
/// so that file stays under SwiftLint's 400-line `file_length` cap after the
/// autocomplete storage and content-tier partition wiring landed. Same
/// extension-split pattern the `+T643` / `+T637` helpers already follow; the
/// state these methods touch is `internal` on the main type for the same
/// reason.
extension SearchViewModel {

    /// Debounced search kick-off, called from `query`'s `didSet`. A query under
    /// the 2-char floor resets to idle (bumping the generation so an earlier
    /// in-flight ≥2-char search bails); otherwise it schedules `performSearch`
    /// after the debounce.
    func scheduleSearch() {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            // DUT-221: bump the generation so an earlier ≥2-char search in flight bails.
            searchGeneration &+= 1
            items = []
            ingredientItems = []  // DUT-11: don't strand a stale tier.
            state = .idle
            didYouMean = nil  // DUT-568: parity with clear() — wipe the rescue banner.
            filterSupportHydrated = false  // DUT-505: re-arm lazy filter-support hydration.
            return
        }
        debounceTask = Task { [weak self] in
            guard let self else { return }
            let delay = self.debounceMilliseconds
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
            if Task.isCancelled { return }
            await self.performSearch()
        }
    }

    /// Run one search pass: claim a generation, fan out the REST paths, split
    /// the response into the title tier + the surviving content tier (v2 Search
    /// overhaul 2/3), fold in the local ingredient index, and hand off to the
    /// finalize hop in `+T643`.
    func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        // H1: claim a new generation; stale async completions check it + bail.
        searchGeneration &+= 1
        let generation = searchGeneration

        // The local ingredient index works offline; the REST pass does not. We
        // try both and gracefully degrade (see the DUT-11 tier below).
        let online = await dependencies.isOnline()
        // H1: a newer search may have settled to `.results` mid-await; without
        // this, `state = .searching` below strands the UI in a spinner.
        guard generation == searchGeneration else { return }
        state = .searching
        let fanOut = await fanOutSearchPaths(trimmed: trimmed, online: online)

        // DUT-11: the local "Recipes using <term>" tier — works offline.
        let localItems =
            (try? await dependencies.recipesUsingIngredient(matching: trimmed)) ?? []

        // v2 Search overhaul (2/3): split the `?search=` response into the
        // title tier (primary `items`) AND the content tier (recipes WP
        // returned for a body/ingredient match — the catalog-wide "recipes
        // using this term"). The content tier used to be discarded by the
        // title-precision filter; it now survives as `partition.contentMatches`.
        let partition = SearchResultMerger.partition(
            query: trimmed,
            restResults: fanOut.restResults
        )
        // T-643 / CL-121: union the title-tier-ordered Path A results
        // with the category-fetched Path B results, deduped by post id.
        // Path A's tier ordering (exact → substring → fuzzy) survives the
        // union; Path B-only contributions append in WP's natural date-
        // desc order. See `CategoryNameMatcher` doc-comment for the rule.
        let merged = mergeWithCategoryResults(
            titleMerged: partition.titleMatches,
            categoryResults: fanOut.categoryResults
        )

        // DUT-11 + v2 Search overhaul (2/3): build the "Recipes Using <term>"
        // tier from the server content matches (WP relevance order) plus the
        // local ingredient index (offline supplement), deduped against the
        // title tier + offline guard + cache stash (`finishTextSearch` lives in
        // `+T643`). DUT-622: `restFailed` rides along so a failed request with
        // no fallback surfaces `.error`.
        await finishTextSearch(
            merged: merged,
            usingSources: .init(contentMatches: partition.contentMatches, localItems: localItems),
            trimmed: trimmed,
            network: .init(online: online, restFailed: fanOut.restFailed),
            generation: generation
        )
    }
}
