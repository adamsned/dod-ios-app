import DODDomain
import Foundation
import SwiftData
import Testing

@testable import DODPersistence

/// DUT-572 / CL-310: the four editorial `CachedRecipe` columns
/// (recipeCategory / recipeCuisine / suitableForDiet / author) added for the
/// redesigned recipe page.
///
/// These are additive optional/defaulted attributes absorbed by SwiftData's
/// same-version inference — the `articleBodyHTML` pattern — NOT a new versioned
/// schema for THESE four columns (a schema bump with no new entity collides
/// fingerprints with the prior version and trips "Duplicate version checksums
/// detected"; see the `MigrationPlan` header). This suite proves the current
/// container opens cleanly through the migration plan, an on-disk store
/// round-trips the new columns, and the full store write→read path preserves
/// the fields (incl. the DUT-399 don't-clobber convention).
///
/// **Keep the hardcoded schema below current.** Unlike the other tests in this
/// file (which call `RecipeStore.inMemoryContainer()` / go through
/// `RecipeStore`, so they always exercise whatever schema is "current"),
/// `onDiskStoreReopensCleanlyThroughMigrationPlanWithDefaults` hardcodes an
/// explicit `Schema(SchemaVn.*)` literal to control the on-disk upgrade
/// precisely. DUT-943 Scope A bumped production to `SchemaV7` (an ACTUAL new
/// entity, `SyncedProfile` — unlike DUT-572's four columns above, which
/// stayed same-version); this file's literal was bumped alongside it
/// (V6 -> V7) because leaving it pinned to a stale "current" version makes
/// SwiftData build concurrent `ModelContainer`s that disagree on which
/// version is current for the SAME `@Model` classes across suites running in
/// parallel — which reproducibly corrupts the shared `NSEntityDescription`
/// cache and crashes the test process (`"Can't assign an object to a store
/// that does not contain the object's entity"`). Bump this literal again the
/// next time the production schema version changes.
///
/// `.serialized` for the same reason as the other schema suites: version-specific
/// `ModelContainer`s share one `NSEntityDescription` per `@Model` across
/// containers, so building several at once in one process can mis-route a
/// cross-store insert. Production opens exactly one container.
@Suite("Recipe editorial columns (DUT-572)", .serialized) struct RecipeEditorialColumnsTests {

    @Test func currentContainerExposesEditorialColumns() throws {
        // The current container (built through the same schema production uses)
        // opens cleanly and a CachedRecipe row round-trips the new columns.
        let container = try RecipeStore.inMemoryContainer()
        let context = ModelContext(container)
        context.insert(
            CachedRecipe(
                id: 11,
                slug: "corn",
                title: "Corn",
                excerptText: "",
                canonicalURLString: "https://example.com/11",
                publishedAt: .distantPast,
                recipeCategory: ["Side Dish"],
                recipeCuisine: ["American"],
                suitableForDiet: ["https://schema.org/LowFatDiet"],
                author: "Chef Ned"
            )
        )
        try context.save()
        let row = try #require(
            try context.fetch(
                FetchDescriptor<CachedRecipe>(predicate: #Predicate { $0.id == 11 })
            ).first
        )
        #expect(row.recipeCategory == ["Side Dish"])
        #expect(row.recipeCuisine == ["American"])
        #expect(row.suitableForDiet == ["https://schema.org/LowFatDiet"])
        #expect(row.author == "Chef Ned")
    }

    /// An on-disk store created through the migration plan reopens cleanly
    /// through the migration plan and preserves rows — the launch-crash guard.
    /// The store is version-stamped by the plan (as the shipped app stamps a
    /// real user's store), so the reopen exercises the same staged-migration
    /// resolution production hits. A row written without the editorial columns
    /// reads back with the defaulted values, proving the additive attributes are
    /// absorbed cleanly (no crash, no duplicate-checksum trap).
    /// Builds the V7 two-configuration container for `onDiskStoreReopensCleanlyThroughMigrationPlanWithDefaults`.
    /// Extracted to a suite-level helper (rather than a nested function
    /// inside the test) to keep that test under the SwiftLint
    /// `function_body_length` cap.
    private func openEditorialColumnsContainer(
        defaultStoreURL: URL,
        syncedStoreURL: URL
    ) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(SchemaV7.models),
            migrationPlan: MigrationPlan.self,
            configurations: ModelConfiguration(
                schema: Schema(SchemaV7.localModels),
                url: defaultStoreURL,
                cloudKitDatabase: .none
            ),
            ModelConfiguration(
                schema: Schema(SchemaV7.syncedModels),
                url: syncedStoreURL,
                cloudKitDatabase: .none
            )
        )
    }

    @Test func onDiskStoreReopensCleanlyThroughMigrationPlanWithDefaults() throws {
        // DUT-943 — serialized against the other on-disk version-specific
        // container tests in this target; see `OnDiskSchemaContainerTestLock`.
        try OnDiskSchemaContainerTestLock.withLock {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("dut572-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: dir) }
            let defaultStoreURL = dir.appendingPathComponent("default.store")
            let syncedStoreURL = dir.appendingPathComponent("SyncedSaved.store")

            // Step 1: create + seed the store through the migration plan (version
            // stamped), then release it so the file is closed.
            try autoreleasepool {
                let container = try openEditorialColumnsContainer(
                    defaultStoreURL: defaultStoreURL,
                    syncedStoreURL: syncedStoreURL
                )
                let context = ModelContext(container)
                context.insert(
                    CachedRecipe(
                        id: 909,
                        slug: "seed",
                        title: "Seed Saved Recipe",
                        excerptText: "Seeded without editorial columns.",
                        canonicalURLString: "https://dutchovendaddy.com/909",
                        publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
                        isSaved: true
                    )
                )
                try context.save()
            }

            // Step 2: reopen the SAME store through the migration plan. Must NOT throw.
            let reopened = try openEditorialColumnsContainer(
                defaultStoreURL: defaultStoreURL,
                syncedStoreURL: syncedStoreURL
            )
            let verify = ModelContext(reopened)
            let row = try #require(
                try verify.fetch(
                    FetchDescriptor<CachedRecipe>(predicate: #Predicate { $0.id == 909 })
                ).first
            )
            #expect(row.isSaved == true, "Saved recipe must survive the reopen")
            #expect(row.recipeCategory.isEmpty, "Editorial arrays default to empty")
            #expect(row.recipeCuisine.isEmpty)
            #expect(row.suitableForDiet.isEmpty)
            #expect(row.author == nil, "Author defaults to nil")
        }
    }

    /// The four editorial fields survive the full write→read round-trip:
    /// `mergeDetail` → `applyParsedDetailFields` (persist) → `toDomain` (read).
    @Test func editorialFieldsRoundTripThroughStore() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        let recipe = Recipe(
            id: 321,
            slug: "corn",
            title: "Skillet Corn",
            excerpt: "Easy side.",
            canonicalURL: URL(string: "https://dutchovendaddy.com/corn")
                ?? URL(filePath: "/dev/null"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: [RecipeIngredient(text: "2 cans corn")],
            recipeCategory: ["Side Dish"],
            recipeCuisine: ["American"],
            suitableForDiet: ["https://schema.org/LowFatDiet"],
            author: "Chef Ned"
        )
        try await store.mergeDetail(recipe)

        let read = try #require(try await store.recipe(id: 321))
        #expect(read.recipeCategory == ["Side Dish"])
        #expect(read.recipeCuisine == ["American"])
        #expect(read.suitableForDiet == ["https://schema.org/LowFatDiet"])
        #expect(read.author == "Chef Ned")
    }

    /// `applyParsedDetailFields` must not clobber previously-cached editorial
    /// values with empty/nil on a partial re-parse (DUT-399 convention).
    @Test func partialReparseKeepsCachedEditorialFields() async throws {
        let store = RecipeStore(modelContainer: try RecipeStore.inMemoryContainer())
        let base = URL(string: "https://dutchovendaddy.com/corn") ?? URL(filePath: "/dev/null")

        try await store.mergeDetail(
            Recipe(
                id: 654,
                slug: "corn",
                title: "Skillet Corn",
                excerpt: "Easy side.",
                canonicalURL: base,
                publishedAt: .distantPast,
                recipeCategory: ["Side Dish"],
                recipeCuisine: ["American"],
                suitableForDiet: ["https://schema.org/LowFatDiet"],
                author: "Chef Ned"
            )
        )
        // A re-parse that omits them (empty arrays / nil author) must NOT wipe
        // the cached values.
        try await store.mergeDetail(
            Recipe(
                id: 654,
                slug: "corn",
                title: "Skillet Corn",
                excerpt: "Easy side.",
                canonicalURL: base,
                publishedAt: .distantPast
            )
        )

        let read = try #require(try await store.recipe(id: 654))
        #expect(read.recipeCategory == ["Side Dish"])
        #expect(read.recipeCuisine == ["American"])
        #expect(read.suitableForDiet == ["https://schema.org/LowFatDiet"])
        #expect(read.author == "Chef Ned")
    }
}
