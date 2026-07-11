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
///
/// `.serialized`: these tests each spin up version-specific `ModelContainer`s
/// (V3, V4, V5, and the on-disk upgrade). SwiftData shares a single
/// `NSEntityDescription` per `@Model` class across containers, so creating
/// several at once in one process can mis-route a cross-store insert
/// ("Can't assign an object to a store that does not contain the object's
/// entity"). Production opens exactly one container, so this is purely a
/// test-process concurrency artifact; serializing the suite removes it.
@Suite("SchemaV5 (DUT-35)", .serialized) struct SchemaV5Tests {

    @Test func v3ToV5LightweightMigrationOpensCleanly() throws {
        // DUT-943 — serialized against the other version-specific container
        // tests in this target; see `OnDiskSchemaContainerTestLock`.
        try OnDiskSchemaContainerTestLock.withLock {
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

    /// The real build-14 upgrade, on disk: write a pre-V5 store in the OLD
    /// single-configuration layout (the same `Schema(SchemaV4.models)` the
    /// shipped `productionContainer` used), then reopen that exact file under
    /// the V5 two-configuration layout + migration plan. This is the one path
    /// the in-memory tests can't exercise -- a botched store-to-store migration
    /// here would crash every user on launch, not just sync users.
    ///
    /// Scope: asserts the upgrade OPENS and preserves saved rows (the
    /// launch-crash risk). It deliberately does NOT drive `backfillSyncedSaved`
    /// -- a cross-store INSERT into an on-disk synced store mis-routes when
    /// several version-specific containers coexist in one parallel test process
    /// (a SwiftData test-harness artifact; the app opens exactly one
    /// container). The backfill is covered against an in-memory two-config
    /// container by `SyncedSavedRecipeTests`.
    @Test func v4OnDiskStoreUpgradesToV5PreservingSaves() throws {
        // DUT-943 — serialized against the other on-disk version-specific
        // container tests in this target; see `OnDiskSchemaContainerTestLock`.
        try OnDiskSchemaContainerTestLock.withLock {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("dut35-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }
            let defaultStoreURL = dir.appendingPathComponent("default.store")
            let syncedStoreURL = dir.appendingPathComponent("SyncedSaved.store")

            // Step 1: write the pre-V5 on-disk store (all six models, one saved
            // recipe) exactly as builds <= 13 left it.
            try seedLegacyV4Store(at: defaultStoreURL)

            // Step 2: open the SAME default.store under the V5 two-configuration
            // layout + migration plan, with the new SyncedSaved store alongside.
            // This is the build-14 upgrade and must NOT throw.
            let localConfig = ModelConfiguration(
                schema: Schema(SchemaV5.localModels),
                url: defaultStoreURL,
                cloudKitDatabase: .none
            )
            let syncedConfig = ModelConfiguration(
                schema: Schema(SchemaV5.syncedModels),
                url: syncedStoreURL,
                cloudKitDatabase: .none
            )
            let upgraded = try ModelContainer(
                for: Schema(SchemaV5.models),
                migrationPlan: MigrationPlan.self,
                configurations: localConfig,
                syncedConfig
            )

            let verify = ModelContext(upgraded)
            // The legacy saved recipe survives the upgrade in default.store.
            let legacy = try verify.fetch(
                FetchDescriptor<CachedRecipe>(predicate: #Predicate { $0.id == 808 })
            ).first
            #expect(legacy?.isSaved == true, "Legacy saved recipe must survive the V4 -> V5 upgrade")
            // The newly-created synced store opened and is queryable (empty until
            // the launch backfill seeds it).
            let synced = try verify.fetch(FetchDescriptor<SyncedSavedRecipe>())
            #expect(synced.isEmpty, "SyncedSaved store must open empty and queryable post-upgrade")
        }
    }

    /// Write a pre-V5 store at `url` in the OLD single-configuration layout
    /// (all six models, `Schema(SchemaV4.models)`) holding one saved recipe.
    /// The container is released when this returns, so the store is closed
    /// before the upgrade reopens the same file.
    private func seedLegacyV4Store(at url: URL) throws {
        let config = ModelConfiguration(
            schema: Schema(SchemaV4.models),
            url: url,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: Schema(SchemaV4.models), configurations: config)
        let context = ModelContext(container)
        context.insert(
            CachedRecipe(
                id: 808,
                slug: "legacy",
                title: "Legacy Saved Recipe",
                excerptText: "Saved before the upgrade.",
                canonicalURLString: "https://dutchovendaddy.com/808",
                publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
                isSaved: true
            )
        )
        try context.save()
    }
}
