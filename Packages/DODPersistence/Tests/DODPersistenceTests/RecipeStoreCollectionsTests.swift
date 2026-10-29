import DODDomain
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// DUT-105: recipe collections / cookbooks. CRUD over the synced
/// `SyncedRecipeCollection`, the many-to-many membership (a recipe in more than
/// one collection), the collection detail read, reorder, and the unsave prune.
/// Runs on the same two-configuration in-memory container the app uses.
@Suite("RecipeStore collections (DUT-105)")
struct RecipeStoreCollectionsTests {

    private func url(_ string: String) -> URL {
        URL(string: string) ?? URL(filePath: "/dev/null")
    }

    private func listItem(id: Int, title: String) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: title,
            excerpt: "Excerpt \(id)",
            heroImage: url("https://dutchovendaddy.com/\(id).jpg"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil,
            canonicalURL: url("https://dutchovendaddy.com/\(id)")
        )
    }

    /// Cache + save a recipe so it's a member of the saved set (collections are
    /// subsets of it).
    private func save(_ store: RecipeStore, id: Int, title: String) async throws {
        try await store.cache(listItem: listItem(id: id, title: title))
        _ = try await store.toggleSaved(id: id)
    }

    @Test("Create appends, list is ordered, rename + delete work")
    func createRenameDelete() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        let camping = try await store.createCollection(name: "Camping")
        let breads = try await store.createCollection(name: "Breads")

        var all = try await store.collections()
        #expect(all.map(\.name) == ["Camping", "Breads"], "Newest appends after the first")
        #expect(breads.sortOrder > camping.sortOrder)

        try await store.renameCollection(id: camping.id, name: "Camping Trips")
        all = try await store.collections()
        #expect(all.first?.name == "Camping Trips")

        try await store.deleteCollection(id: camping.id)
        all = try await store.collections()
        #expect(all.map(\.name) == ["Breads"])
    }

    @Test("A recipe can live in multiple collections (many-to-many)")
    func manyToMany() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await save(store, id: 1, title: "Skillet Cornbread")
        let camping = try await store.createCollection(name: "Camping")
        let breads = try await store.createCollection(name: "Breads")

        try await store.setCollections(forRecipe: 1, to: [camping.id, breads.id])

        #expect(try await store.collectionIDs(forRecipe: 1) == [camping.id, breads.id])
        #expect(try await store.recipes(inCollection: camping.id).map(\.id) == [1])
        #expect(try await store.recipes(inCollection: breads.id).map(\.id) == [1])
    }

    @Test("setCollections adds and removes to match the target set")
    func setCollectionsSyncsMembership() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await save(store, id: 1, title: "Chili")
        let alpha = try await store.createCollection(name: "A")
        let beta = try await store.createCollection(name: "B")

        try await store.setCollections(forRecipe: 1, to: [alpha.id, beta.id])
        #expect(try await store.collectionIDs(forRecipe: 1) == [alpha.id, beta.id])

        // Drop B, keep A — the removal side of the sync.
        try await store.setCollections(forRecipe: 1, to: [alpha.id])
        #expect(try await store.collectionIDs(forRecipe: 1) == [alpha.id])
        #expect(try await store.recipes(inCollection: beta.id).isEmpty)
    }

    @Test("Collection detail returns members in add order, saved-only")
    func collectionDetailOrderAndFilter() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await save(store, id: 10, title: "Ten")
        try await save(store, id: 20, title: "Twenty")
        let dinner = try await store.createCollection(name: "Dinner")

        try await store.setCollections(forRecipe: 20, to: [dinner.id])
        try await store.setCollections(forRecipe: 10, to: [dinner.id])
        // Add order is 20 then 10, so detail preserves that order.
        #expect(try await store.recipes(inCollection: dinner.id).map(\.id) == [20, 10])
    }

    @Test("Unsaving a recipe prunes it from every collection")
    func unsavePrunesMembership() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await save(store, id: 1, title: "Bread")
        let breads = try await store.createCollection(name: "Breads")
        try await store.setCollections(forRecipe: 1, to: [breads.id])
        #expect(try await store.recipes(inCollection: breads.id).map(\.id) == [1])

        // Unsave it — it should leave the collection.
        _ = try await store.toggleSaved(id: 1)
        #expect(try await store.collectionIDs(forRecipe: 1).isEmpty)
        #expect(try await store.recipes(inCollection: breads.id).isEmpty)
    }

    @Test("Reorder rewrites the shelf order")
    func reorder() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        let alpha = try await store.createCollection(name: "A")
        let beta = try await store.createCollection(name: "B")
        let gamma = try await store.createCollection(name: "C")

        try await store.reorderCollections(orderedIDs: [gamma.id, alpha.id, beta.id])
        #expect(try await store.collections().map(\.name) == ["C", "A", "B"])
    }

    @Test("recipeCount reflects membership")
    func recipeCount() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await save(store, id: 1, title: "One")
        try await save(store, id: 2, title: "Two")
        let weeknight = try await store.createCollection(name: "Quick Weeknight")
        try await store.setCollections(forRecipe: 1, to: [weeknight.id])
        try await store.setCollections(forRecipe: 2, to: [weeknight.id])
        let reloaded = try await store.collections().first { $0.id == weeknight.id }
        #expect(reloaded?.recipeCount == 2)
    }
}
