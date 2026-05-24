import Foundation
import SwiftData

/// Schema V1 — the initial persistent shape shipped in v1.0.
///
/// **Migration rule (R-5):** future schema changes are additive-only.
/// Never delete or rename a stored field on a `@Model`; always add a new
/// optional field and migrate values lazily. The migration plan template
/// in ``MigrationPlan`` enforces this discipline.
public enum SchemaV1: VersionedSchema {

    public static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [CachedRecipe.self, CachedListPage.self, CachedImage.self]
    }
}

/// Schema V2 — adds the local ingredient search index (US-12, CL-19).
///
/// The only change vs V1 is the additive `CachedIngredient` model. No existing
/// fields are renamed or removed; no existing rows need transformation. That
/// makes this a **lightweight** migration — SwiftData handles the schema
/// extension at container open. Rows in the new table are populated lazily on
/// each subsequent `RecipeStore.mergeDetail(_:)` call; until then, search
/// silently falls back to the REST title/excerpt result set (no error path).
public enum SchemaV2: VersionedSchema {

    public static var versionIdentifier: Schema.Version {
        Schema.Version(2, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [CachedRecipe.self, CachedListPage.self, CachedImage.self, CachedIngredient.self]
    }
}

/// Migration plan. V1 -> V2 is lightweight because V2 is V1 plus one new
/// model. Per MIGRATION.md rule 3 there is a migration test
/// (`MigrationTests.lightweightV1toV2OpensCleanly`) that asserts a V1 store
/// opens under V2 without data loss.
public enum MigrationPlan: SchemaMigrationPlan {

    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}
