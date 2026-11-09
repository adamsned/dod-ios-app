import Foundation

/// DUT-131 — offline-sync bookkeeping for "Keep saved recipes available offline".
extension RecipeStore {
    /// Saved recipe ids that have NOT yet been explicitly downloaded.
    /// Saved-and-downloaded ids are excluded; downloaded-but-unsaved ids are ignored.
    public func savedRecipeIDsPendingDownload() throws -> Set<Int> {
        try savedRecipeIDs().subtracting(downloadedRecipeIDs())
    }
}
