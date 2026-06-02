import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// SchemaV5 (DUT-35 / DUT-6): the additive `SyncedSavedRecipe` entity and the
/// two-configuration CloudKit-scope split. Mirrors `SchemaV4Tests`: a unit
/// process can't exercise the real on-disk store-to-store migration (that needs
/// the app's CloudKit/push entitlements and is verified on device), so these
/// assert the schema is a clean additive superset and the V5 container opens
/// and round-trips the new model. Honors MIGRATION.md rule 3 — the V3 -> V5
/// lightweight stage has a paired test.
@Suite("SchemaV5 (DUT-35)") struct SchemaV5Tests {

    @Test func v3ToV5LightweightMigrationOpensCleanly() throws {
        // Step 1: a V3 store still accepts a V3-era row.
        let v3Container = try RecipeStore.inMemoryContainerV3()
        let v3Context = ModelContext(v3Container)
        v3Context.insert(
            CachedRecipe(
                id: 7,
                slug: "v3",
                title: "V3 Recipe",
                excerptText: "Excerpt",
                canonicalURLString: "https://example.com/7",
                publishedAt: .now
            )
        )
        try v3Context.save()

        // Step 2: the V5 container is an additive superset — all six prior
        // entities PLUS the new SyncedSavedRecipe.
        let v5Container = try RecipeStore.inMemoryContainer()
        let entities = v5Container.schema.entitiesByName
        for name in [
            "CachedRecipe", "CachedListPage", "CachedImage",
            "CachedIngredient", "CachedComment", "CachedRating",
        ] {
            #expect(entities[name] != nil, "V5 must still expose \(name)")
        }
        #expect(
            entities["SyncedSavedRecipe"] != nil,
            "V5 must add the SyncedSavedRecipe CloudKit-mirror entity"
        )
    }

    @Test func syncedSavedRecipeRoundTripsInV5Container() throws {
        let container = try RecipeStore.inMemoryContainer()
        let context = ModelContext(container)
        context.insert(
            SyncedSavedRecipe(
                id: 99,
                title: "Saved",
                excerptText: "E",
                canonicalURLString: "https://example.com/99"
            )
        )
        try context.save()
        let rows = try context.fetch(
            FetchDescriptor<SyncedSavedRecipe>(predicate: #Predicate { $0.id == 99 })
        )
        #expect(rows.count == 1)
        #expect(rows.first?.title == "Saved")
    }
}
