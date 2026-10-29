import DODDomain
import DODSupport
import Foundation

/// v2 Search overhaul (2/3) — type-ahead autocomplete. As the user types
/// (before the debounced result fetch settles), a short list of matching
/// recipe titles appears under the search field; tapping one runs that search.
///
/// Sources: the local cached-title pool (`dependencies.cachedRecipeTitles()`),
/// loaded ONCE and then filtered synchronously per keystroke so typing never
/// blocks on the network — the offline/instant path the spec asks for. The
/// pure ranking lives in `DODSupport.SearchAutocomplete`; this extension owns
/// the debounce + stale-drop + pool caching, mirroring the search pipeline's
/// `searchGeneration` guard so a slow pool-load for an earlier keystroke can't
/// clobber a newer query's suggestions.
///
/// Split into its own file so `SearchViewModel.swift` stays under SwiftLint's
/// `file_length` cap — the same extension-split pattern the T-637 / T-643
/// helpers already follow.
extension SearchViewModel {

    /// Cap on how many suggestions are shown at once — enough to be useful,
    /// few enough not to bury the field.
    static let maxSuggestions = 6

    /// Debounced recompute of `suggestions`, called from `query`'s `didSet`.
    /// Cancels any in-flight pass, bumps the autocomplete generation, and
    /// (after the short debounce) loads the title pool if needed and filters
    /// it. A query under the matcher's 2-char floor clears the list outright.
    func scheduleAutocomplete() {
        autocompleteTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        autocompleteGeneration &+= 1
        guard trimmed.count >= SearchAutocomplete.minimumQueryLength else {
            suggestions = []
            return
        }
        let generation = autocompleteGeneration
        autocompleteTask = Task { [weak self] in
            guard let self else { return }
            let delay = self.autocompleteDebounceMilliseconds
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
            if Task.isCancelled { return }
            await self.recomputeSuggestions(trimmed: trimmed, generation: generation)
        }
    }

    /// For tests: bypass the debounce and recompute suggestions immediately for
    /// the current query.
    public func runImmediateAutocomplete() async {
        autocompleteTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        autocompleteGeneration &+= 1
        guard trimmed.count >= SearchAutocomplete.minimumQueryLength else {
            suggestions = []
            return
        }
        await recomputeSuggestions(trimmed: trimmed, generation: autocompleteGeneration)
    }

    /// Load the cached-title pool if it hasn't been fetched yet, then set
    /// `suggestions` from it — but only if `generation` is still current
    /// (stale-drop: a newer keystroke that superseded us must win).
    private func recomputeSuggestions(trimmed: String, generation: Int) async {
        await loadTitlePoolIfNeeded()
        guard generation == autocompleteGeneration else { return }
        suggestions = SearchAutocomplete.suggestions(
            query: trimmed,
            titles: cachedTitlePool,
            limit: Self.maxSuggestions
        )
    }

    /// Fetch the cached recipe titles once per session. The pool is purely
    /// local (no REST); a cold cache yields an empty pool → no suggestions,
    /// which is the correct fresh-install behaviour.
    func loadTitlePoolIfNeeded() async {
        guard !didLoadTitlePool else { return }
        // Assign BEFORE flipping the flag so a concurrent pass that races in
        // during the await never observes `didLoadTitlePool == true` over an
        // empty pool (it either loads too — a cheap, idempotent re-fetch — or
        // sees the populated pool). The generation guard in the caller drops
        // any stale pass regardless.
        let titles = (try? await dependencies.cachedRecipeTitles()) ?? []
        cachedTitlePool = titles
        didLoadTitlePool = true
    }

    /// Run the search for a tapped suggestion. Clears the suggestion list,
    /// sets the field to the chosen title (which runs the search through the
    /// normal debounce path via `query`'s `didSet`), and commits it as a
    /// finalized recent search — the user deliberately picked it.
    public func applySuggestion(_ title: String) {
        suggestions = []
        query = title
        // The assignment above re-armed a fresh autocomplete pass; cancel it so
        // the just-tapped suggestion doesn't immediately re-surface the list.
        autocompleteTask?.cancel()
        autocompleteGeneration &+= 1
        suggestions = []
        commitRecentSearch()
    }
}
