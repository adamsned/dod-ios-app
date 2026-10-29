import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// SchemaV7 (DUT-105): the additive, synced `SyncedRecipeCollection` model.
/// Mirrors `SchemaV6Tests` — a unit process asserts the V7 schema is a clean
/// additive superset of V6 and that the new entity round-trips. Honors
/// MIGRATION.md rule 3 (the V6 -> V7 lightweight stage has a paired test).
///
/// `.serialized` for the same reason as `SchemaV5Tests` / `SchemaV6Tests`:
/// version-specific `ModelContainer`s share one `NSEntityDescription` per
/// `@Model` across containers, so building several at once in one process can
/// mis-route a cross-store insert. Production opens exactly one container.
@Suite("SchemaV7 (DUT-105)", .serialized) struct SchemaV7Tests {

    @Test func v6ToV7LightweightMigrationOpensCleanly() throws {
        // The current (V7) container must be an additive superset: every prior
        // entity PLUS the new synced SyncedRecipeCollection.
        let container = try RecipeStore.inMemoryContainer()
        let entities = container.schema.entitiesByName
        for name in [
            "CachedRecipe", "CachedListPage", "CachedImage",
            "CachedIngredient", "CachedComment", "CachedRating",
            "SyncedSavedRecipe", "CachedCookLogEntry",
        ] {
            #expect(entities[name] != nil, "V7 must still expose \(name)")
        }
        #expect(
            entities["SyncedRecipeCollection"] != nil,
            "V7 must add the SyncedRecipeCollection collections entity"
        )
    }

    @Test func collectionRoundTripsInV7Container() throws {
        let container = try RecipeStore.inMemoryContainer()
        let context = ModelContext(container)
        let id = UUID()
        context.insert(
            SyncedRecipeCollection(
                id: id,
                name: "Camping",
                sortOrder: 0,
                createdAt: Date(timeIntervalSince1970: 1000),
                recipeIDs: [1, 2, 3]
            )
        )
        try context.save()
        let rows = try context.fetch(
            FetchDescriptor<SyncedRecipeCollection>(predicate: #Predicate { $0.id == id })
        )
        #expect(rows.count == 1)
        #expect(rows.first?.name == "Camping")
        #expect(rows.first?.recipeIDs == [1, 2, 3])
    }

    /// The collections model must satisfy the CloudKit-mirror invariants (it is
    /// synced): no `@Attribute(.unique)` constraints, so its attributes carry no
    /// uniqueness. A regression that re-adds a unique constraint would make the
    /// `.private` container throw at open (DOD-CRASH-1).
    @Test func collectionEntityHasNoUniqueConstraints() throws {
        let container = try RecipeStore.inMemoryContainer()
        let entity = container.schema.entitiesByName["SyncedRecipeCollection"]
        #expect(entity?.uniquenessConstraints.isEmpty == true)
    }
}
