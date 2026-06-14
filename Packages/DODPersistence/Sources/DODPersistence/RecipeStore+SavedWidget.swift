import DODDomain
import Foundation
import SwiftData

/// Narrow projection of a saved recipe shaped for the saved-recipes
/// home-screen widget snapshot (spec.md US-17 / AC-17.3). Carries only the
/// fields the widget needs and exposes a `heroImageCached` flag so the host
/// can populate `SavedRecipesWidgetSnapshot.Entry.heroImageFilename`
/// honestly — the widget extension renders a placeholder for `nil`
/// filenames rather than chasing a network fetch (AC-17.6 forbids
/// widget-side network).
///
/// Lives in DODPersistence (not DODSupport) so this package stays free of
/// any widget-snapshot type knowledge — the consumer (DODFeatureRecipeDetail
/// in the host app) is responsible for the DODSupport conversion. Keeps the
/// DODPersistence ↔ DODSupport dependency direction one-way.
public struct SavedRecipeWidgetRow: Sendable, Equatable {
    public let recipeID: Int
    public let title: String
    public let canonicalURL: URL
    public let heroImageURL: URL?
    /// `true` when the hero image bytes are already in the local image
    /// cache (AC-5.2 pre-download). Drives whether the widget snapshot
    /// carries a filename or `nil`.
    public let heroImageCached: Bool
    /// Drives sort order in the snapshot. We use `CachedRecipe.lastViewedAt`
    /// because the widget renders only locally-present saved rows — those whose
    /// hero bytes can already be in the local image cache (AC-17.6 forbids
    /// widget-side network). Note (DUT-35): the in-app Saved tab now reads the
    /// synced `SyncedSavedRecipe` set ordered by `savedAt`, so the widget's
    /// most-recent-first order can differ slightly from the tab's; that is
    /// acceptable for the home-screen projection, which is intentionally scoped
    /// to rows that have a renderable cached image.
    public let savedAt: Date

    public init(
        recipeID: Int,
        title: String,
        canonicalURL: URL,
        heroImageURL: URL?,
        heroImageCached: Bool,
        savedAt: Date
    ) {
        self.recipeID = recipeID
        self.title = title
        self.canonicalURL = canonicalURL
        self.heroImageURL = heroImageURL
        self.heroImageCached = heroImageCached
        self.savedAt = savedAt
    }
}

extension RecipeStore {

    /// T-765 / CL-162 (DUT-71) — the id set of every saved recipe, read from
    /// the synced source of truth (same rows ``isSaved(id:)`` / ``savedRecipes()``
    /// use). Lightweight projection (no `toDomain` stitch) for the card
    /// long-press menu to render the correct Save/Unsave label on every surface.
    public func savedRecipeIDs() throws -> Set<Int> {
        let descriptor = FetchDescriptor<SyncedSavedRecipe>()
        return Set(try modelContext.fetch(descriptor).map(\.id))
    }

    /// T-774 / CL-171 (DUT-80) — the id set of every recipe explicitly
    /// downloaded for offline use (``CachedRecipe/downloadedAt`` `!= nil`, set
    /// by ``markDownloaded(id:)``). The Saved tab intersects this with its
    /// displayed (saved) recipes to render a "Downloaded" badge on the cards
    /// that are saved AND downloaded (vs. saved-only). Download state lives on
    /// the local ``CachedRecipe`` (it is NOT CloudKit-synced, per DUT-35), so
    /// this reads the cache table rather than ``SyncedSavedRecipe``.
    public func downloadedRecipeIDs() throws -> Set<Int> {
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { $0.downloadedAt != nil }
        )
        return Set(try modelContext.fetch(descriptor).map(\.id))
    }

    /// Fetch the most-recently-saved recipes, projected into the narrow
    /// shape the saved-recipes widget snapshot needs (spec.md US-17 /
    /// AC-17.3). Sorted by `lastViewedAt` descending, capped at `limit`.
    ///
    /// Rows whose `canonicalURLString` is empty or unparseable are skipped
    /// — the widget tap-through requires a usable URL (AC-17.4) and a
    /// missing one would just render a dead row.
    public func savedRecipesForWidget(limit: Int) throws -> [SavedRecipeWidgetRow] {
        guard limit > 0 else { return [] }
        var descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { $0.isSaved == true },
            sortBy: [SortDescriptor(\.lastViewedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let rows = try modelContext.fetch(descriptor)
        return rows.compactMap { row -> SavedRecipeWidgetRow? in
            guard !row.canonicalURLString.isEmpty,
                let canonical = URL(string: row.canonicalURLString)
            else { return nil }
            let heroImageURL = row.heroImageURLString.flatMap { URL(string: $0) }
            let cached =
                heroImageURL.map { imageBytesAreCached(forURLString: $0.absoluteString) } ?? false
            return SavedRecipeWidgetRow(
                recipeID: row.id,
                title: row.title,
                canonicalURL: canonical,
                heroImageURL: heroImageURL,
                heroImageCached: cached,
                savedAt: row.lastViewedAt
            )
        }
    }

    /// Probe whether the bytes for `urlString` are already present in the
    /// `CachedImage` table. Avoids the public ``image(url:)`` accessor
    /// here because it bumps `lastUsedAt` — widget-snapshot generation
    /// should not promote a row in the image LRU (parity with
    /// `recipeWithoutTouching` for the recipe LRU).
    private func imageBytesAreCached(forURLString urlString: String) -> Bool {
        let descriptor = FetchDescriptor<CachedImage>(
            predicate: #Predicate { $0.urlString == urlString }
        )
        return (try? modelContext.fetch(descriptor).first) != nil
    }
}
