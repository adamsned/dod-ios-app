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
    /// synced store, so re-running it is harmless.
    ///
    /// DUT-240 — the one-shot flag alone does NOT prevent cross-device
    /// resurrection (the first run could still seed a stale local pin before
    /// the remote unsave imported). The caller
    /// (`AppDependencies.backfillSyncedSavedIfNeeded`) owns that protection:
    /// with CloudKit sync live it defers this seed until the first finished
    /// import and skips it entirely when the imported set is already non-empty.
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

    /// True when the recipe is saved. Reads the synced source of truth (so the
    /// bookmark glyph reflects a save made on another device even before the
    /// local `CachedRecipe` pin is reconciled on detail open), plus — pre-backfill
    /// only — the DUT-470 provisional local pin (a legacy save the CloudKit
    /// mirror hasn't landed yet). Moved here from `RecipeStore.swift` for the
    /// file_length cap.
    public func isSaved(id: Int) throws -> Bool {
        if try fetchSyncedSaved(id: id) != nil { return true }
        // DUT-470: pre-backfill, a legacy local pin (no synced row) is a real
        // not-yet-mirrored save — reflect it so the glyph matches the Saved tab.
        if !didBackfillSyncedSaved { return try fetchRecipe(id: id)?.isSaved == true }
        return false
    }

    /// DUT-240 — true when ANY synced saved-row exists. After the first
    /// CloudKit import lands, a non-empty set means another ≥V5 device already
    /// seeded the shared set — so the launch-time backfill must NOT re-insert
    /// local-only pins (their absence from the set IS the user's cross-device
    /// unsave). Cheap: `fetchLimit = 1`.
    public func hasAnySyncedSaved() throws -> Bool {
        var descriptor = FetchDescriptor<SyncedSavedRecipe>()
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }

    /// DUT-468 — the id set of all synced saved-rows. The launch backfill
    /// snapshots this BEFORE the import wait (the baseline) and re-reads it
    /// after, so it can tell import-delivered rows apart from a local save made
    /// during the wait. Unlike ``hasAnySyncedSaved()`` this can't be poisoned by
    /// a single local save because the caller subtracts the baseline and the
    /// locally-pinned ids (see ``locallyPinnedSavedIDSet()``).
    public func syncedSavedIDSet() throws -> Set<Int> {
        Set(try modelContext.fetch(FetchDescriptor<SyncedSavedRecipe>()).map(\.id))
    }

    /// DUT-468 — the id set of local `isSaved` pins. `toggleSaved` sets this
    /// pin AND writes the synced row in one transaction, whereas a CloudKit
    /// import inserts the synced row WITHOUT a pin (the pin is reconciled later
    /// in `mergeDetail`). So "synced row present, no pin" marks an
    /// import-delivered save — the signal the backfill uses to detect that a
    /// ≥V5 device already owns the set.
    public func locallyPinnedSavedIDSet() throws -> Set<Int> {
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { $0.isSaved == true }
        )
        return Set(try modelContext.fetch(descriptor).map(\.id))
    }

    /// DUT-470 — the local `isSaved` pins to surface for DISPLAY as a
    /// *provisional* saved-set, newest-viewed first, but ONLY while the one-time
    /// backfill hasn't completed.
    ///
    /// The gap this closes: with sync ON but the CloudKit mirror unavailable
    /// (signed out of iCloud, CK account trouble), no import ever fires, so the
    /// synced `SyncedSavedRecipe` set stays empty and the Saved tab is blank
    /// every launch — even though the upgrader's legacy pins are real saves.
    ///
    /// These pins live on `CachedRecipe`, which is in the LOCAL-ONLY
    /// configuration (`cloudKitDatabase: .none`), so surfacing them for display
    /// writes NOTHING to the CloudKit mirror — it cannot resurrect a cross-device
    /// unsave (the DUT-240 / DUT-468 hazard). Once the first real import
    /// reconciles and `didBackfillSyncedSaved` flips (seed OR skip), the synced
    /// set becomes authoritative and this returns `[]`, so stale local-only pins
    /// (cross-device unsaves) correctly stop showing. This is the read-time
    /// half of the "provisional seed, reconciled on sign-in" fix — no separate
    /// mirrored model needed, because the local pins already ARE the local-only
    /// provisional store.
    func provisionalSavedPins() throws -> [CachedRecipe] {
        guard !didBackfillSyncedSaved else { return [] }
        let descriptor = FetchDescriptor<CachedRecipe>(
            predicate: #Predicate { $0.isSaved == true },
            sortBy: [SortDescriptor(\.lastViewedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
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
