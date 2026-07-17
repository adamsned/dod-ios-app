import DODDomain
import DODSupport
import Foundation

// v2 Search overhaul (1/3) — "Surprise Me" moved OFF the Feed header and ONTO
// the Search page's idle state. The behavior lives here (split out of
// `SearchViewModel.swift` to keep that file under the SwiftLint 400-line
// `file_length` cap); the `isSurpriseMeLoading` / `lastSurpriseID` stored
// properties stay on `SearchViewModel` itself (extensions can't add stored
// properties). Mirrors the Feed's `FeedViewModel+SurpriseMe.swift` one-to-one.

extension SearchViewModel {

    /// Fetch ONE truly-random recipe from the WHOLE WP catalog
    /// (`dependencies.fetchRandomRecipe()`, server-side `orderby=rand`) and hand
    /// it to the Search screen's EXISTING recipe-open path, `onSelect` — the same
    /// closure a result-card tap already calls (``SearchView``'s injected
    /// closure, which the App shell wires to `path.append(.recipe(...))`). The
    /// view model doesn't own navigation itself, so the caller (the idle button's
    /// action in `SearchView`) threads its own `onSelect` through rather than this
    /// type inventing a second navigation seam.
    ///
    /// The network fetch samples the entire catalog. The in-memory
    /// `RandomRecipePicker` sample over the current result `items` is kept ONLY as
    /// a fallback for when the fetch fails (offline, server error, decode
    /// failure). On the idle Search page `items` is usually empty (no query has
    /// run), so the fallback is typically a no-op — but it's wired for parity with
    /// the Feed and to cover the mid-session case where results are on screen.
    ///
    /// Re-entrancy: a tap that arrives while a previous fetch is still in flight
    /// is a no-op (guarded by `isSurpriseMeLoading`). Tracks `lastSurpriseID` so
    /// back-to-back fallback taps don't show the same recipe twice in a row
    /// (`RandomRecipePicker` filters it out of the candidate pool).
    public func surpriseMe(onSelect: (RecipeListItem) -> Void) async {
        guard !isSurpriseMeLoading else { return }
        isSurpriseMeLoading = true
        defer { isSurpriseMeLoading = false }
        do {
            let item = try await dependencies.fetchRandomRecipe()
            lastSurpriseID = item.id
            onSelect(item)
            return
        } catch {
            DODLog.network.error(
                "surpriseMe: full-catalog fetch failed, falling back to in-memory sample: \(String(describing: error))"
            )
        }
        // Fallback: sample the in-memory result set so the button still does
        // something on a server error when results happen to be on screen.
        guard
            let id = RandomRecipePicker.pick(from: items.map(\.id), excluding: lastSurpriseID),
            let item = items.first(where: { $0.id == id })
        else { return }
        lastSurpriseID = id
        onSelect(item)
    }
}
