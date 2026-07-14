import DODDomain
import DODSupport
import Foundation

// DUT-1062 — "Surprise Me" (originally DUT-939), split out of
// `FeedViewModel.swift` to keep that file under the SwiftLint 400-line
// `file_length` cap (mirrors the `+ShoppingList` / `+SaveToggle` splits).
// `lastSurpriseID` and `isSurpriseMeLoading` remain stored properties on
// `FeedViewModel` itself (extensions can't add stored properties); only the
// behavior lives here.

extension FeedViewModel {

    /// DUT-939 / DUT-1062 — "Surprise Me": fetch ONE truly-random recipe from
    /// the WHOLE WP catalog (`dependencies.fetchRandomRecipe()`, server-side
    /// `orderby=rand`) and hand it to the feed's EXISTING recipe-open path,
    /// `onSelect` (`FeedView`'s own closure — the same one every card tap
    /// already calls, per `FeedView+ShoppingList.recipeCardTap`). The view
    /// model doesn't own navigation itself, so the caller (the button's
    /// action in `FeedView`) threads its own `onSelect` through rather than
    /// this type inventing a second, parallel navigation seam.
    ///
    /// DUT-1062: the original DUT-939 implementation sampled only `items`
    /// (whatever's paged into memory at tap time, roughly the first ~20-40
    /// recipes a session has scrolled through), so repeated taps kept
    /// resurfacing the same handful instead of feeling serendipitous. The
    /// network fetch now samples the entire catalog; the old in-memory
    /// `RandomRecipePicker` sample over `items` is kept ONLY as a fallback
    /// for when the fetch fails (offline, server error, decode failure) so
    /// the button never goes dead without connectivity.
    ///
    /// Re-entrancy: a tap that arrives while a previous fetch is still in
    /// flight is a no-op (mirrors `addToShoppingList`'s per-item in-flight
    /// guard via `addingIDs`). No-op when the feed has no items AND the
    /// network fetch fails. Tracks `lastSurpriseID` so back-to-back
    /// fallback taps don't show the same recipe twice in a row
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
        // Fallback: sample the in-memory loaded feed (pre-DUT-1062 behavior)
        // so the button still works offline / on a server error.
        guard
            let id = RandomRecipePicker.pick(from: items.map(\.id), excluding: lastSurpriseID),
            let item = items.first(where: { $0.id == id })
        else { return }
        lastSurpriseID = id
        onSelect(item)
    }
}
