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
        recents.record(trimmed)
        recentSearches = recents.recent()
    }
}
