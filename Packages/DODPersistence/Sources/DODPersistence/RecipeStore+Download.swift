import Foundation
import SwiftData

/// Explicit-download mutations that don't fit in `RecipeStore.swift` (pinned
/// at SwiftLint's 400-line `file_length` cap). The download *marker* lives on
/// ``CachedRecipe/downloadedAt``; ``RecipeStore/markDownloaded(id:)`` (in the
/// main file) sets it, this clears it. Read-side projections live alongside
/// the widget code in `RecipeStore+SavedWidget.swift`
/// (``RecipeStore/downloadedRecipeIDs()``).
extension RecipeStore {

    /// Clear the explicit-download pin so the recipe reverts to *saved-only*
    /// (``CachedRecipe/downloadedAt`` → `nil`) — the inverse of
    /// ``markDownloaded(id:)`` (T-775 / DUT-81).
    ///
    /// The row stays saved + cached and its hero image stays **pinned**: the
    /// AC-4.9 "fully usable offline if saved" / AC-5.2 pre-download contract is
    /// keyed to the *saved* state, not the download flag, so un-downloading
    /// must NOT drop the offline image bytes (image un-pinning is the unsave
    /// path's concern, gated on `isSaved == false`).
    ///
    /// Idempotent: returns `true` when the recipe was downloaded (state
    /// changed), `false` when it wasn't downloaded to begin with (or the row
    /// is absent) so the caller can skip redundant UI churn.
    @discardableResult
    public func removeDownload(id: Int) throws -> Bool {
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { $0.id == id }
        )
        guard let row = try modelContext.fetch(descriptor).first,
            row.downloadedAt != nil
        else { return false }
        row.downloadedAt = nil
        try modelContext.save()
        return true
    }

    /// DUT-999 — which of `urls` already have a cached image row. Read-only:
    /// does not bump `lastUsedAt` and does not fault the byte blobs.
    public func cachedImageURLs(among urls: [URL]) throws -> Set<URL> {
        var found = Set<URL>()
        for url in urls {
            let urlString = url.absoluteString
            var descriptor = FetchDescriptor<CachedImage>(
                predicate: #Predicate { $0.urlString == urlString }
            )
            descriptor.propertiesToFetch = [\.urlString]
            descriptor.fetchLimit = 1
            if try !modelContext.fetch(descriptor).isEmpty { found.insert(url) }
        }
        return found
    }
}
