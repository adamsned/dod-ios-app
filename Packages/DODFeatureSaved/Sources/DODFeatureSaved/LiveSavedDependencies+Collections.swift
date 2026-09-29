import DODDomain
import DODPersistence
import Foundation

// DUT-105 — live collections wiring: route the Saved tab's collections shelf +
// "Add to Collection" sheet to `RecipeStore`'s collection CRUD.
extension LiveSavedDependencies {

    public func collections() async throws -> [RecipeCollection] {
        try await store.collections()
    }

    public func createCollection(name: String) async throws -> RecipeCollection {
        try await store.createCollection(name: name)
    }

    public func renameCollection(id: UUID, name: String) async throws {
        try await store.renameCollection(id: id, name: name)
    }

    public func deleteCollection(id: UUID) async throws {
        try await store.deleteCollection(id: id)
    }

    public func collectionIDs(forRecipe recipeID: Int) async throws -> Set<UUID> {
        try await store.collectionIDs(forRecipe: recipeID)
    }

    public func setCollections(forRecipe recipeID: Int, to ids: Set<UUID>) async throws {
        try await store.setCollections(forRecipe: recipeID, to: ids)
    }

    public func recipes(inCollection id: UUID) async throws -> [Recipe] {
        try await store.recipes(inCollection: id)
    }

    public func reorderCollections(orderedIDs: [UUID]) async throws {
        try await store.reorderCollections(orderedIDs: orderedIDs)
    }
}
