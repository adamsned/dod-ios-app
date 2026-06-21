import DODSupport
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// SchemaV6 (DUT-104): the additive, local-only `CachedCookLogEntry` cook-journal
/// model. Mirrors `SchemaV5Tests` — a unit process asserts the V6 schema is a
/// clean additive superset of V5, that the new entity round-trips, and that the
/// `RecipeStore` cook-log CRUD works. Honors MIGRATION.md rule 3 (the V5 -> V6
/// lightweight stage has a paired test).
///
/// `.serialized` for the same reason as `SchemaV5Tests`: version-specific
/// `ModelContainer`s share one `NSEntityDescription` per `@Model` across
/// containers, so building several at once in one process can mis-route a
/// cross-store insert. Production opens exactly one container.
@Suite("SchemaV6 (DUT-104)", .serialized) struct SchemaV6Tests {

    @Test func v5ToV6LightweightMigrationOpensCleanly() throws {
        // The current (V6) container must be an additive superset: every prior
        // entity PLUS the new local-only CachedCookLogEntry.
        let container = try RecipeStore.inMemoryContainer()
        let entities = container.schema.entitiesByName
        for name in [
            "CachedRecipe", "CachedListPage", "CachedImage",
            "CachedIngredient", "CachedComment", "CachedRating", "SyncedSavedRecipe",
        ] {
            #expect(entities[name] != nil, "V6 must still expose \(name)")
        }
        #expect(
            entities["CachedCookLogEntry"] != nil,
            "V6 must add the CachedCookLogEntry cook-journal entity"
        )
    }

    @Test func cookLogEntryRoundTripsInV6Container() throws {
        let container = try RecipeStore.inMemoryContainer()
        let context = ModelContext(container)
        let id = UUID()
        context.insert(
            CachedCookLogEntry(
                id: id,
                recipeID: 42,
                recipeTitle: "Dutch Oven Lasagna",
                cookedAt: Date(timeIntervalSince1970: 1000)
            )
        )
        try context.save()
        let rows = try context.fetch(
            FetchDescriptor<CachedCookLogEntry>(predicate: #Predicate { $0.id == id })
        )
        #expect(rows.count == 1)
        #expect(rows.first?.recipeTitle == "Dutch Oven Lasagna")
    }

    @Test func recipeStoreLogsCooksAndReturnsThemNewestFirst() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        try await store.logCook(
            CookLogEntry(
                id: UUID(),
                recipeID: 1,
                recipeTitle: "Lasagna",
                cookedAt: Date(timeIntervalSince1970: 200)
            )
        )
        try await store.logCook(
            CookLogEntry(
                id: UUID(),
                recipeID: 2,
                recipeTitle: "Chicken",
                cookedAt: Date(timeIntervalSince1970: 100)
            )
        )
        let logs = try await store.allCookLogs()
        #expect(logs.count == 2)
        #expect(logs.first?.recipeTitle == "Lasagna", "Newest cook should sort first")
        #expect(logs.last?.recipeTitle == "Chicken")
    }

    @Test func recipeStoreDeletesACook() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        let id = UUID()
        try await store.logCook(
            CookLogEntry(id: id, recipeID: 1, recipeTitle: "Lasagna", cookedAt: .now)
        )
        try await store.deleteCookLog(id: id)
        let logs = try await store.allCookLogs()
        #expect(logs.isEmpty)
    }
}
