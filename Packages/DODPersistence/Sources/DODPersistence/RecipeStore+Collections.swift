import DODDomain
import Foundation
import SwiftData

// MARK: - Recipe collections / cookbooks (DUT-105)
//
// CRUD + membership over `SyncedRecipeCollection`, the second CloudKit-mirrored
// model. Collections group the saved set into named cookbooks; membership is a
// plain `[Int]` id list on the collection row (no `@Relationship`), matching the
// synced store's "join by id" design (see `SyncedRecipeCollection.swift`).
// Factored out of `RecipeStore.swift` to keep that file under the SwiftLint
// `file_length` cap.
extension RecipeStore {

    // MARK: Read

    /// Every collection, ordered for the shelf: by ``SyncedRecipeCollection/sortOrder``
    /// ascending, ties broken by ``SyncedRecipeCollection/createdAt`` oldest
    /// first, so the order is always deterministic. Duplicate rows (CloudKit can
    /// leave two records for one id, since the model carries no unique
    /// constraint) collapse to the first, mirroring `fetchSyncedSaved`.
    public func collections() throws -> [RecipeCollection] {
        var seen = Set<UUID>()
        var result: [RecipeCollection] = []
        for row in try fetchAllCollectionRows() where seen.insert(row.id).inserted {
            result.append(Self.toDomain(row))
        }
        return result
    }

    /// The set of collection ids the recipe currently belongs to — the seed the
    /// "Add to Collection" sheet uses to render each collection's checkmark.
    public func collectionIDs(forRecipe recipeID: Int) throws -> Set<UUID> {
        var ids = Set<UUID>()
        for row in try fetchAllCollectionRows() where row.recipeIDs.contains(recipeID) {
            ids.insert(row.id)
        }
        return ids
    }

    /// The saved recipes in a collection, in the order they were added. Filtered
    /// to recipes that are still saved (an unsaved recipe is pruned from every
    /// collection, so this normally returns all of them); a recipe saved on
    /// another device surfaces here once its synced saved-row has imported, with
    /// detail hydrating on first open like the flat Saved list.
    public func recipes(inCollection collectionID: UUID) throws -> [Recipe] {
        guard let row = try fetchCollectionRow(id: collectionID) else { return [] }
        let savedByID = Dictionary(
            try savedRecipesWithSavedAt().map { ($0.recipe.id, $0.recipe) },
            uniquingKeysWith: { first, _ in first }
        )
        return row.recipeIDs.compactMap { savedByID[$0] }
    }

    // MARK: Create / rename / delete

    /// Create a new collection with `name`, appended after the current maximum
    /// ``SyncedRecipeCollection/sortOrder``. Returns the created value.
    @discardableResult
    public func createCollection(name: String) throws -> RecipeCollection {
        let nextOrder = (try fetchAllCollectionRows().map(\.sortOrder).max() ?? -1) + 1
        let row = SyncedRecipeCollection(name: name, sortOrder: nextOrder, createdAt: .now)
        modelContext.insert(row)
        try modelContext.save()
        return Self.toDomain(row)
    }

    /// Rename a collection. Tolerates CloudKit duplicates by renaming every row
    /// for the id. No-op if the id is unknown.
    public func renameCollection(id: UUID, name: String) throws {
        let rows = try fetchAllCollectionRows(id: id)
        guard !rows.isEmpty else { return }
        for row in rows { row.name = name }
        try modelContext.save()
    }

    /// Delete a collection (every row for the id). The recipes themselves stay
    /// saved — a collection is only a grouping.
    public func deleteCollection(id: UUID) throws {
        for row in try fetchAllCollectionRows(id: id) {
            modelContext.delete(row)
        }
        try modelContext.save()
    }

    // MARK: Membership

    /// Set exactly which collections a recipe belongs to, adding it to every id
    /// in `collectionIDs` and removing it from the rest. One save covers all the
    /// membership edits the "Add to Collection" sheet makes.
    public func setCollections(forRecipe recipeID: Int, to collectionIDs: Set<UUID>) throws {
        for row in try fetchAllCollectionRows() {
            let isMember = row.recipeIDs.contains(recipeID)
            let shouldBeMember = collectionIDs.contains(row.id)
            if shouldBeMember, !isMember {
                row.recipeIDs.append(recipeID)
            } else if !shouldBeMember, isMember {
                row.recipeIDs.removeAll { $0 == recipeID }
            }
        }
        try modelContext.save()
    }

    /// Reorder the shelf by rewriting ``SyncedRecipeCollection/sortOrder`` to
    /// each id's position in `orderedIDs`. Ids not listed keep their order after
    /// the listed ones. Nice-to-have reorder support (DUT-105).
    public func reorderCollections(orderedIDs: [UUID]) throws {
        var position = 0
        for id in orderedIDs {
            for row in try fetchAllCollectionRows(id: id) {
                row.sortOrder = position
            }
            position += 1
        }
        try modelContext.save()
    }

    /// Remove a recipe from every collection it belongs to. Called from the
    /// unsave paths so collection membership stays a subset of the saved set.
    /// Does NOT call `save()` — the unsave caller (`toggleSaved`, `mergeDetail`)
    /// owns the transaction boundary that already writes both stores at once.
    func pruneRecipeFromCollections(id recipeID: Int) throws {
        for row in try fetchAllCollectionRows() where row.recipeIDs.contains(recipeID) {
            row.recipeIDs.removeAll { $0 == recipeID }
        }
    }

    // MARK: Helpers

    /// All collection rows, shelf-ordered (`sortOrder` asc, then `createdAt` asc).
    func fetchAllCollectionRows() throws -> [SyncedRecipeCollection] {
        let descriptor = FetchDescriptor<SyncedRecipeCollection>(
            sortBy: [
                SortDescriptor(\.sortOrder, order: .forward),
                SortDescriptor(\.createdAt, order: .forward),
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    /// All rows for one collection id (normally one; CloudKit can leave dupes).
    func fetchAllCollectionRows(id: UUID) throws -> [SyncedRecipeCollection] {
        let descriptor = FetchDescriptor<SyncedRecipeCollection>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor)
    }

    /// The earliest-created row for a collection id, tolerating CloudKit dupes.
    func fetchCollectionRow(id: UUID) throws -> SyncedRecipeCollection? {
        try fetchAllCollectionRows(id: id).min { $0.createdAt < $1.createdAt }
    }

    static func toDomain(_ row: SyncedRecipeCollection) -> RecipeCollection {
        RecipeCollection(
            id: row.id,
            name: row.name,
            sortOrder: row.sortOrder,
            createdAt: row.createdAt,
            recipeIDs: row.recipeIDs
        )
    }
}
