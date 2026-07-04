import DODSupport
import Foundation
import SwiftData

/// Cook-journal persistence (US-48 / DUT-104) — the store side of the "I Made
/// This" journal. CRUD over the local-only `CachedCookLogEntry`, converting
/// to/from the pure ``CookLogEntry`` value type at the boundary so the schema
/// stays primitive-only (the same Cached*↔value pattern as comments/ratings).
///
/// The pure ``CookLogStats`` calculator runs over the `[CookLogEntry]` that
/// ``allCookLogs()`` returns, so streaks / most-cooked / busiest-month need no
/// store logic of their own.
extension RecipeStore {

    #if DEBUG
    /// DUT-473 test-only: arm/disarm the ``logCook`` save failpoint on THIS
    /// actor instance (see ``cookLogSaveFailpointError``).
    func setCookLogSaveFailpointForTesting(_ error: Error?) {
        cookLogSaveFailpointError = error
    }
    #endif

    /// Append one cook to the private journal.
    public func logCook(_ entry: CookLogEntry) throws {
        // DUT-345: idempotency. A double-tap / retry mints a fresh `id` (UUID) each
        // call, so dedup on the natural key — the same recipe logged within a few
        // seconds is a duplicate, not a second cook.
        let recipeID = entry.recipeID
        let lower = entry.cookedAt.addingTimeInterval(-3)
        let upper = entry.cookedAt.addingTimeInterval(3)
        let recent = FetchDescriptor<CachedCookLogEntry>(
            predicate: #Predicate { $0.recipeID == recipeID && $0.cookedAt >= lower && $0.cookedAt <= upper }
        )
        if let existing = try? modelContext.fetch(recent), !existing.isEmpty {
            // DUT-423: the caller already wrote the photo JPEG to disk before calling
            // us; on a dedup skip, delete it so it doesn't orphan (no row will ever
            // reference its `photoLocalID`, so the DUT-338 cleanup can't reach it).
            if let photoID = entry.photoLocalID { CookPhotoStore().delete(id: photoID) }
            return
        }
        let inserted = CachedCookLogEntry(
            id: entry.id,
            recipeID: entry.recipeID,
            recipeTitle: entry.recipeTitle,
            cookedAt: entry.cookedAt,
            note: entry.note,
            personalRating: entry.personalRating,
            photoLocalID: entry.photoLocalID
        )
        modelContext.insert(inserted)
        do {
            #if DEBUG
            if let error = cookLogSaveFailpointError { throw error }  // DUT-473 test seam
            #endif
            try modelContext.save()
        } catch {
            // DUT-473: `save()` threw AFTER the insert. The `@ModelActor`'s
            // context is long-lived with autosave OFF, so the still-pending row
            // would ride along on the NEXT successful `save()` from any other
            // store write (`cache(listItem:)`, `toggleSaved`) — a phantom cook
            // whose `photoLocalID` points at a JPEG the caller (FeedViewModel /
            // RecipeDetailViewModel+CookLog, per DUT-208) deletes on this throw.
            // Roll the insert back and delete our just-written photo too, so a
            // failed log leaves neither a ghost row nor an orphaned file —
            // mirroring the DUT-423 dedup-skip cleanup above.
            modelContext.delete(inserted)
            if let photoID = entry.photoLocalID { CookPhotoStore().delete(id: photoID) }
            throw error
        }
    }

    /// Update one journal entry's editable, personal fields (reflection note /
    /// personal rating / photo). No-op if the id isn't there.
    ///
    /// CL-273 — this updates an EXISTING row in place; it never inserts. Rank is
    /// derived from `allCookLogs().count` (see ``CookProgression``), so editing a
    /// reflection or photo cannot change the cook count and therefore cannot
    /// affect rank. That separation is the whole point of the personal journal.
    public func updateCookLog(_ entry: CookLogEntry) throws {
        let id = entry.id
        let descriptor = FetchDescriptor<CachedCookLogEntry>(
            predicate: #Predicate { $0.id == id }
        )
        guard let row = try modelContext.fetch(descriptor).first else {
            // DUT-515: the caller (CookJournalEntryView.save) writes the new photo
            // JPEG to disk BEFORE calling us. If the row is gone (e.g. deleted out
            // from under an open edit), the just-written file would orphan in
            // Application Support — no row will ever reference its `photoLocalID`,
            // so the DUT-338 cleanup below can't reach it. Delete it here,
            // mirroring the DUT-423 dedup-branch cleanup in `logCook`.
            if let photoID = entry.photoLocalID { CookPhotoStore().delete(id: photoID) }
            return
        }
        // DUT-338: if the photo was replaced or cleared, delete the previous
        // file so it doesn't orphan in Application Support (never OS-purged).
        // The new file, if any, is already on disk by the time we get here.
        let previousPhotoID = row.photoLocalID
        row.note = entry.note
        row.personalRating = entry.personalRating
        row.photoLocalID = entry.photoLocalID
        if let previousPhotoID, previousPhotoID != entry.photoLocalID {
            CookPhotoStore().delete(id: previousPhotoID)
        }
        try modelContext.save()
    }

    /// Every logged cook, newest first.
    public func allCookLogs() throws -> [CookLogEntry] {
        let descriptor = FetchDescriptor<CachedCookLogEntry>(
            sortBy: [SortDescriptor(\.cookedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(Self.toDomain)
    }

    /// Delete one journal entry by id (no-op if it isn't there).
    public func deleteCookLog(id: UUID) throws {
        let descriptor = FetchDescriptor<CachedCookLogEntry>(
            predicate: #Predicate { $0.id == id }
        )
        let photoStore = CookPhotoStore()
        for row in try modelContext.fetch(descriptor) {
            // DUT-338: drop the entry's photo file too — deleting only the row
            // leaves the JPEG orphaned in Application Support forever.
            if let photoLocalID = row.photoLocalID {
                photoStore.delete(id: photoLocalID)
            }
            modelContext.delete(row)
        }
        try modelContext.save()
    }

    private static func toDomain(_ row: CachedCookLogEntry) -> CookLogEntry {
        CookLogEntry(
            id: row.id,
            recipeID: row.recipeID,
            recipeTitle: row.recipeTitle,
            cookedAt: row.cookedAt,
            note: row.note,
            personalRating: row.personalRating,
            photoLocalID: row.photoLocalID
        )
    }
}
