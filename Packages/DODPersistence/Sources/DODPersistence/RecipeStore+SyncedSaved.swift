import DODDomain
import Foundation
import SwiftData

// MARK: - Synced saved-recipe set (DUT-35 / DUT-6)
//
// `SyncedSavedRecipe` is the ONLY model mirrored to CloudKit. It is the synced
// source of truth for the Saved tab; `CachedRecipe.isSaved` stays a local pin
// (LRU / widget / bookmark glyph) that `RecipeStore` keeps reconciled. These
// helpers are factored out of `RecipeStore.swift` to keep that file under the
// SwiftLint `file_length` cap. See `SyncedSavedRecipe.swift` and
// `RecipeStore+Containers.swift` for the model and the two-configuration split.
extension RecipeStore {

    /// All synced rows for a recipe id, earliest save first. Normally one, but
    /// CloudKit can leave duplicate records: the mirrored `SyncedSavedRecipe`
    /// model can carry no `@Attribute(.unique)` (CloudKit forbids it), so two
    /// devices saving the same recipe offline each insert their own CKRecord and
    /// nothing collapses them. Every id lookup therefore tolerates duplicates
    /// (DUT-378).
    func fetchAllSyncedSaved(id: Int) throws -> [SyncedSavedRecipe] {
        let descriptor = FetchDescriptor<SyncedSavedRecipe>(
            predicate: #Predicate { $0.id == id },
            sortBy: [SortDescriptor(\.savedAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Look up the synced saved-row for a recipe id, if the user has it saved.
    /// Returns the earliest of any CloudKit-duplicate rows (DUT-378).
    func fetchSyncedSaved(id: Int) throws -> SyncedSavedRecipe? {
        try fetchAllSyncedSaved(id: id).first
    }

    /// Insert-or-update the synced saved-row from a `CachedRecipe`'s display
    /// fields. Does NOT call `save()` — the caller (`toggleSaved`,
    /// `backfillSyncedSaved`) owns the transaction boundary. On update,
    /// `savedAt` is preserved so re-opening or re-merging a saved recipe never
    /// reshuffles the Saved tab's newest-first order.
    func upsertSyncedSaved(from row: CachedRecipe) throws {
        let isArticle = row.jsonLDFailedAt != nil && !(row.articleBodyHTML ?? "").isEmpty
        let existingRows = try fetchAllSyncedSaved(id: row.id)
        if let existing = existingRows.first {
            // DUT-378: collapse any CloudKit-duplicate rows into the earliest one
            // so the set converges to a single record for this id.
            for duplicate in existingRows.dropFirst() {
                modelContext.delete(duplicate)
            }
            existing.title = row.title
            existing.excerptText = row.excerptText
            existing.canonicalURLString = row.canonicalURLString
            existing.heroImageURLString = row.heroImageURLString
            existing.totalSeconds = row.totalSeconds
            existing.publishedAt = row.publishedAt
            existing.isArticle = isArticle
        } else {
            modelContext.insert(
                SyncedSavedRecipe(
                    id: row.id,
                    savedAt: .now,
                    title: row.title,
                    excerptText: row.excerptText,
                    canonicalURLString: row.canonicalURLString,
                    heroImageURLString: row.heroImageURLString,
                    totalSeconds: row.totalSeconds,
                    publishedAt: row.publishedAt,
                    isArticle: isArticle
                )
            )
        }
    }

    /// Drop the synced saved-row for a recipe id (the unsave path). Does NOT
    /// call `save()` — the caller owns the transaction boundary.
    func removeSyncedSaved(id: Int) throws {
        // DUT-378: delete ALL rows for the id, not just the first — CloudKit may
        // have left duplicate records, and removing only one leaves a zombie save
        // that keeps the recipe in the Saved tab and reads `isSaved == true`.
        for existing in try fetchAllSyncedSaved(id: id) {
            modelContext.delete(existing)
        }
    }

    /// One-time backfill (DUT-35): seed the synced store from any pre-V5 local
    /// saves so the Saved tab is NOT empty after the update that introduced
    /// `SyncedSavedRecipe`. Idempotent — it only inserts ids not already in the
    /// synced store, so re-running it is harmless. The caller
    /// (`AppDependencies.bootstrap`) still guards it behind a one-shot
    /// `UserDefaults` flag so a later cross-device unsave is never resurrected
    /// by a device whose stale local pin still reads `isSaved == true`.
    public func backfillSyncedSaved() throws {
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { $0.isSaved == true }
        )
        var inserted = 0
        for row in try modelContext.fetch(descriptor)
        where try fetchSyncedSaved(id: row.id) == nil {
            try upsertSyncedSaved(from: row)
            inserted += 1
        }
        if inserted > 0 {
            try modelContext.save()
        }
    }

    /// DUT-302: the App calls this from `bootstrap` once the one-time backfill
    /// has completed (or was already done on a prior launch), flipping
    /// ``mergeDetail`` from "preserve legacy pins" to "synced set is authoritative".
    public func markSyncedSavedBackfillComplete() {
        didBackfillSyncedSaved = true
    }

    #if DEBUG
    /// Test-only: simulate a pre-V5 legacy save — a local `isSaved` pin with NO
    /// synced row — to exercise the DUT-302 mergeDetail-before-backfill race.
    func seedLegacyLocalSaveForTesting(id: Int) throws {
        guard let row = try fetchRecipe(id: id) else { return }
        row.isSaved = true
        try removeSyncedSaved(id: id)
        try modelContext.save()
    }

    /// Test-only: read the LOCAL `CachedRecipe.isSaved` pin (the value DUT-302
    /// guards). `isSaved(id:)` reads the synced set, so it can't observe the pin.
    func localIsSavedPinForTesting(id: Int) throws -> Bool {
        try fetchRecipe(id: id)?.isSaved ?? false
    }
    #endif

    /// Map a synced saved-row to a Domain `Recipe` for the Saved tab. The
    /// result is intentionally PARTIAL — title, excerpt, hero image, total
    /// time, canonical URL, and kind are enough to render the Saved card and
    /// route to detail; ingredients/instructions/nutrition stay empty and
    /// hydrate from the network on first detail open (full recipe content is
    /// never synced).
    static func toDomain(_ synced: SyncedSavedRecipe) -> Recipe {
        let canonical = URL(string: synced.canonicalURLString) ?? URL(filePath: "/dev/null")
        return Recipe(
            id: synced.id,
            slug: "",
            title: synced.title,
            excerpt: synced.excerptText,
            canonicalURL: canonical,
            heroImage: synced.heroImageURLString.flatMap { URL(string: $0) },
            heroImageLargeURL: nil,
            categoryIDs: [],
            publishedAt: synced.publishedAt,
            ingredients: [],
            instructions: [],
            prepTime: nil,
            cookTime: nil,
            totalTime: synced.totalSeconds.map { .seconds($0) },
            servings: nil,
            nutrition: nil,
            video: nil,
            kind: synced.isArticle ? .article : .recipe,
            articleBodyHTML: nil
        )
    }
}
