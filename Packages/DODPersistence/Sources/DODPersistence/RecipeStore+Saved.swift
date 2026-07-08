import Foundation
import SwiftData

// US-5 / DUT-35 — the save toggle + the idempotent mark-saved (download = save).
// Extracted from `RecipeStore.swift` so that file stays under the SwiftLint
// `file_length` cap.
extension RecipeStore {

    @discardableResult
    public func toggleSaved(id: Int) throws -> Bool {
        guard let row = try fetchRecipe(id: id) else { return false }
        // DUT-732: decide save-vs-unsave from the SYNCED source of truth, not the
        // local `isSaved` pin. A recipe saved on another device and imported via
        // CloudKit surfaces in the Saved tab with its local pin still `false` (the
        // pin is only reconciled when its detail is opened on this device), so
        // toggling the pin alone would RE-SAVE it instead of removing it. Treat
        // "currently saved" as "a synced row exists OR the local pin is set", then
        // flip that — `isSaved(id:)` already unions the pre-backfill provisional
        // pins, matching every other saved surface.
        let currentlySaved = try isSaved(id: id) || row.isSaved
        row.isSaved = !currentlySaved
        // DUT-35: mirror the local pin into the synced source of truth (only
        // `SyncedSavedRecipe` leaves the device; the recipe cache stays local).
        if row.isSaved {
            try upsertSyncedSaved(from: row)
            // DUT-292: pin the hero so a merely-saved recipe survives image
            // eviction + Settings "free up space" and stays offline-usable (AC-5.2).
            try pinHeroImage(heroURLString: row.heroImageURLString, toRecipeID: id)
        } else {
            try removeSyncedSaved(id: id)
            try tearDownUnsavedPins(row)
        }
        try modelContext.save()
        try evictIfNeeded()
        return row.isSaved
    }

    /// DUT-215 / DUT-512: teardown an unsaved recipe's offline footprint. Must be
    /// run whenever a recipe transitions saved → unsaved (explicit ``toggleSaved``
    /// OR a cross-device unsave observed in ``mergeDetail``), else the
    /// `CachedRecipe` (with `downloadedAt` still set) is never evicted (the
    /// predicate needs `downloadedAt == nil`) and the pinned hero bytes leak
    /// against the image budget forever — un-reclaimable by eviction OR the
    /// Settings "free up space" clear. Callers own the `modelContext.save()`.
    func tearDownUnsavedPins(_ row: CachedRecipe) throws {
        row.downloadedAt = nil
        try unpinImages(forRecipeID: row.id)
    }

    /// T-761 / CL-158 (DUT-67) — idempotently pin a recipe SAVED without
    /// toggling, mirroring the synced row like ``toggleSaved(id:)`` (download =
    /// save + pin). Returns `true` on unsaved → saved, `false` if already saved.
    @discardableResult
    public func markSaved(id: Int) throws -> Bool {
        guard let row = try fetchRecipe(id: id) else { return false }
        if row.isSaved { return false }
        row.isSaved = true
        try upsertSyncedSaved(from: row)
        // DUT-292: pin the hero (download = save + pin) so it's offline-usable.
        try pinHeroImage(heroURLString: row.heroImageURLString, toRecipeID: id)
        try modelContext.save()
        return true
    }
}
