import DODDomain
import Foundation

// DUT-105 — default implementations for the collections surface, so fake
// conformers that don't model collections keep compiling and a build with no
// live store simply shows no collections. `LiveSavedDependencies` overrides all
// of these (see `LiveSavedDependencies+Collections.swift`).
extension SavedDependencies {

    public func collections() async throws -> [RecipeCollection] { [] }

    public func createCollection(name: String) async throws -> RecipeCollection {
        RecipeCollection(id: UUID(), name: name, sortOrder: 0, createdAt: .now, recipeIDs: [])
    }

    public func renameCollection(id: UUID, name: String) async throws {}

    public func deleteCollection(id: UUID) async throws {}

    public func collectionIDs(forRecipe recipeID: Int) async throws -> Set<UUID> { [] }

    public func setCollections(forRecipe recipeID: Int, to ids: Set<UUID>) async throws {}

    public func recipes(inCollection id: UUID) async throws -> [Recipe] { [] }

    public func reorderCollections(orderedIDs: [UUID]) async throws {}
}
