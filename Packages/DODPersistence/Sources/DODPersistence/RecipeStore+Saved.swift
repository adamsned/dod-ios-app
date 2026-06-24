import Foundation
import SwiftData

// US-5 / DUT-35 — the save toggle + the idempotent mark-saved (download = save).
// Extracted from `RecipeStore.swift` so that file stays under the SwiftLint
// `file_length` cap.
extension RecipeStore {

    @discardableResult
    public func toggleSaved(id: Int) throws -> Bool {
        guard let row = try fetchRecipe(id: id) else { return false }
        row.isSaved.toggle()
        // DUT-35: mirror the local pin into the synced source of truth (only
        // `SyncedSavedRecipe` leaves the device; the recipe cache stays local).
        if row.isSaved {
            try upsertSyncedSaved(from: row)
            // DUT-292: pin the hero so a merely-saved recipe survives image
            // eviction + Settings "free up space" and stays offline-usable (AC-5.2).
            try pinHeroImage(heroURLString: row.heroImageURLString, toRecipeID: id)
        } else {
            try removeSyncedSaved(id: id)
            // DUT-215: unsaving must also tear down the offline download + the
            // image pins, else the CachedRecipe (downloadedAt still set) is never
            // evicted (the predicate needs `downloadedAt == nil`) and the pinned
            // hero bytes leak against the image budget forever — un-reclaimable
            // by eviction OR the Settings "free up space" clear.
            row.downloadedAt = nil
            try unpinImages(forRecipeID: id)
        }
        try modelContext.save()
        try evictIfNeeded()
        return row.isSaved
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
