import DODDomain
import Foundation

// MARK: - Recipe collections (DUT-1340)
//
// The data-only seam behind the long-press "Add to Collection" picker. Recipe
// detail deliberately does NOT depend on `DODFeatureSaved` (where the Saved
// tab's own collection UI lives) — the same isolation the DUT-534
// `appendToShoppingList` seam keeps — so collections DATA is routed through the
// protocol instead. `LiveRecipeDetailDependencies` already holds the
// `RecipeStore`, so its impls forward straight to the store's public collection
// CRUD (see `RecipeStore+Collections.swift`). The protocol defaults keep every
// existing fake compiling without opting in.

extension RecipeDetailDependencies {

    /// Default empty list so fakes that don't model collections keep compiling.
    public func collections() async throws -> [RecipeCollection] { [] }

    /// Default returns a throwaway value so fakes keep compiling; only the live
    /// wiring actually persists a new collection.
    public func createCollection(name: String) async throws -> RecipeCollection {
        RecipeCollection(id: UUID(), name: name, sortOrder: 0, createdAt: .now, recipeIDs: [])
    }

    /// Default empty membership so fakes keep compiling.
    public func collectionIDs(forRecipe recipeID: Int) async throws -> Set<UUID> { [] }

    /// Default no-op so fakes that don't model collections keep compiling.
    public func setCollections(forRecipe recipeID: Int, to collectionIDs: Set<UUID>) async throws {}
}

extension LiveRecipeDetailDependencies {

    public func collections() async throws -> [RecipeCollection] {
        try await store.collections()
    }

    public func createCollection(name: String) async throws -> RecipeCollection {
        try await store.createCollection(name: name)
    }

    public func collectionIDs(forRecipe recipeID: Int) async throws -> Set<UUID> {
        try await store.collectionIDs(forRecipe: recipeID)
    }

    public func setCollections(forRecipe recipeID: Int, to collectionIDs: Set<UUID>) async throws {
        try await store.setCollections(forRecipe: recipeID, to: collectionIDs)
    }
}
