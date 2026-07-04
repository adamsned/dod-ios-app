import Foundation

/// T-779 / DUT-85 — recent-searches recording, decoupled from the live
/// (debounced) search so a Recent chip reflects a *committed* search (Return
/// or keyboard dismissal) rather than every mid-typing pause. Lives in its own
/// file so `SearchViewModel.swift` stays under SwiftLint's `file_length` cap.
extension SearchViewModel {

    /// Record the current query into the recent-searches store. Wired in
    /// ``SearchView`` to the search field's `.onSubmit` (Return) and its
    /// focus-loss callback (keyboard dismissal). Skips curated-"Try" taps
    /// (REG-19 / CL-66 — the user tapped a pill, didn't type it) and queries
    /// under 2 characters (mirrors the live-search threshold).
    public func commitRecentSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, !queryFromCuratedTap else { return }
        // DUT-435: Return fires BOTH `.onSubmit` and (by ending editing) the
        // focus-loss callback — two commits for one finalized search. Skip the
        // duplicate; `query`'s didSet clears the marker so a re-typed search
        // commits (and counts) again.
        guard trimmed != lastCommittedQuery else { return }
        lastCommittedQuery = trimmed
        recents.record(trimmed)
        recentSearches = recents.recent()
        // DUT-254: emit the `recipe_searched` analytics event here — the
        // FINALIZED-search trigger (Return / keyboard dismissal) — so one event
        // equals one finalized search, not one per debounced keystroke.
        Task { await sendSearchTelemetry(trimmed: trimmed) }
    }

    /// Clear every persisted recent search (the "Clear All" affordance) and
    /// refresh the view-bound array. Cancels any in-flight debounce so a
    /// mid-type search can't repopulate a just-cleared list.
    public func clearRecentSearches() {
        debounceTask?.cancel()
        recents.clear()
        recentSearches = recents.recent()
    }

    /// Remove a single term from the persisted recent-searches store
    /// (case-insensitive match per `RecentSearches.remove(_:)`) and
    /// refresh the view-bound `recentSearches` array so the FlowLayout
    /// re-renders without the dropped pill on the next observation tick.
    ///
    /// Spec trace: US-33 / AC-33.3 (per-term context-menu Clear),
    /// CL-57 (recents-store mutations route through the view-model).
    public func removeRecentSearch(_ query: String) {
        recents.remove(query)
        recentSearches = recents.recent()
    }
}
