import Foundation
import SwiftData

// Cross-platform saved-recipe sync (Firestore, shared with the Android app).
// Local saves go out through `savedMirror`; changes from other devices come in
// through `applyRemoteSaved` / `applyRemoteRemoval`, which never call the mirror.
extension RecipeStore {

    public func setSavedMirror(_ mirror: (any SavedRecipeMirror)?) {
        savedMirror = mirror
    }

    /// Every synced save, for the one-time upload when a user signs in on this device.
    public func savedRecipeDocs() throws -> [SavedRecipeDoc] {
        let descriptor = FetchDescriptor<SyncedSavedRecipe>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        var seen = Set<Int>()  // DUT-378: CloudKit can leave duplicate rows
        return try modelContext.fetch(descriptor)
            .filter { seen.insert($0.id).inserted }
            .map(SavedRecipeDoc.init)
    }

    /// A save made or updated on another device. Keeps this device's `savedAt` when
    /// the recipe is already saved, so the Saved tab order doesn't jump.
    public func applyRemoteSaved(_ doc: SavedRecipeDoc) throws {
        if let existing = try fetchSyncedSaved(id: doc.id) {
            existing.title = doc.title
            existing.excerptText = doc.excerpt
            existing.heroImageURLString = doc.imageURL
            existing.canonicalURLString = doc.canonicalURL
            existing.totalSeconds = doc.totalTimeMinutes.map { $0 * 60 }
            existing.isArticle = doc.isArticle
        } else {
            modelContext.insert(
                SyncedSavedRecipe(
                    id: doc.id,
                    savedAt: doc.savedAt,
                    title: doc.title,
                    excerptText: doc.excerpt,
                    canonicalURLString: doc.canonicalURL,
                    heroImageURLString: doc.imageURL,
                    totalSeconds: doc.totalTimeMinutes.map { $0 * 60 },
                    publishedAt: doc.publishedAt,
                    isArticle: doc.isArticle
                )
            )
        }
        try modelContext.save()
    }

    /// A removal made on another device: drop the synced row and this device's
    /// offline pins, the same teardown as an unsave here.
    public func applyRemoteRemoval(id: Int) throws {
        try removeSyncedSaved(id: id)
        if let row = try fetchRecipe(id: id), row.isSaved {
            row.isSaved = false
            try tearDownUnsavedPins(row)
        }
        try modelContext.save()
    }

    /// Called by `toggleSaved` / `markSaved` after they commit.
    func mirrorSavedState(id: Int) throws {
        guard let savedMirror else { return }
        if let row = try fetchSyncedSaved(id: id) {
            savedMirror.saved(SavedRecipeDoc(row))
        } else {
            savedMirror.removed(id: id)
        }
    }
}
