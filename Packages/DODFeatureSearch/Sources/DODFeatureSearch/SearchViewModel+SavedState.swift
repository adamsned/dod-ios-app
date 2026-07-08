import Foundation

/// T-765 / CL-162 (DUT-71) — saved-state helpers for the card long-press
/// Save/Unsave menu, split out of `SearchViewModel.swift` so that file stays
/// under the SwiftLint 400-line `file_length` cap. The `savedRecipeIDs`
/// stored property lives on the main class (stored properties can't live in an
/// extension); only the behavior moves here.
extension SearchViewModel {

    /// Reload the saved-id set from the store (a cheap id projection); called
    /// on every appear so a save made on another surface (recipe detail, the
    /// Saved tab, CloudKit sync) reflects in the card menu's Save/Unsave label.
    public func refreshSavedRecipeIDs() async {
        if let ids = try? await dependencies.savedRecipeIDs() {
            savedRecipeIDs = ids
        }
    }

    /// Optimistically flip a recipe's saved membership on a genuine long-press
    /// toggle so the menu label is correct on re-open without waiting for the
    /// async store round-trip; the next ``refreshSavedRecipeIDs()`` reconciles.
    /// Bumps ``saveToggleCount`` so `SearchView` fires the `.selection` haptic on
    /// this real user toggle only (not on appear/refresh reconciliation).
    public func applyOptimisticSaveToggle(id: Int) {
        toggleSavedMembership(id: id)
        saveToggleCount &+= 1
    }

    /// Failed-write rollback: re-invert the optimistic flip WITHOUT bumping
    /// ``saveToggleCount``, so a save that failed to persist does not fire the
    /// positive `.selection` haptic reserved for genuine user toggles.
    public func revertOptimisticSaveToggle(id: Int) {
        toggleSavedMembership(id: id)
    }

    /// Shared membership flip. Only mutates `savedRecipeIDs`; callers decide
    /// whether the flip counts as a genuine toggle (haptic) or a silent rollback.
    private func toggleSavedMembership(id: Int) {
        if savedRecipeIDs.contains(id) {
            savedRecipeIDs.remove(id)
        } else {
            savedRecipeIDs.insert(id)
        }
    }
}
