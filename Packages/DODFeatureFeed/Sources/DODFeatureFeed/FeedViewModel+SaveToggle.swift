import Foundation

// DUT — the card long-press Save/Unsave state + the genuine-toggle haptic
// counter, split out of `FeedViewModel.swift` to keep that file under the
// SwiftLint 400-line `file_length` cap (mirrors the `FeedViewModel+ShoppingList`
// split). The counter is keyed to genuine user toggles only — appear/refresh
// reconciliation of the saved-id set and failed-write rollbacks stay silent —
// matching the DUT-697 fix in `CategoryRecipesViewModel`.

extension FeedViewModel {

    /// T-765 / CL-162 (DUT-71) — reload the saved-id set from the store. Cheap
    /// (a single id projection); called on every appear so a save made on
    /// another surface (recipe detail, the Saved tab, CloudKit sync) reflects
    /// in the card long-press menu's Save/Unsave label.
    public func refreshSavedRecipeIDs() async {
        if let ids = try? await dependencies.savedRecipeIDs() {
            savedRecipeIDs = ids
        }
    }

    /// Optimistically flip a recipe's saved membership the instant the user
    /// taps the long-press Save/Unsave item, so the menu label is correct on
    /// re-open without waiting for the async store toggle to round-trip
    /// (mirrors ``SavedViewModel``'s optimistic removal). The next
    /// ``refreshSavedRecipeIDs()`` reconciles with the store.
    public func applyOptimisticSaveToggle(id: Int) {
        toggleSavedMembership(id: id)
        // DUT — signal the view to fire the `.selection` haptic on this genuine
        // user toggle only (not on appear/refresh set reconciliation, nor on the
        // failed-write rollback below).
        saveToggleCount &+= 1
    }

    /// Shared membership flip for the optimistic Save/Unsave paths. Only mutates
    /// `savedRecipeIDs` — never touches `saveToggleCount`, so callers decide
    /// whether the flip is a genuine user toggle (haptic) or a rollback (silent).
    private func toggleSavedMembership(id: Int) {
        if savedRecipeIDs.contains(id) {
            savedRecipeIDs.remove(id)
        } else {
            savedRecipeIDs.insert(id)
        }
    }

    /// DUT — failed-write rollback path. Re-inverts the optimistic flip WITHOUT
    /// bumping `saveToggleCount`, so a save that failed does not fire the
    /// positive `.selection` haptic reserved for genuine user toggles (mirrors
    /// `CategoryRecipesViewModel.revertOptimisticSaveToggle`).
    func revertOptimisticSaveToggle(id: Int) {
        toggleSavedMembership(id: id)
    }
}
