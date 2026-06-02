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

/// Migration plan.
///
/// - V1 → V2: lightweight (V2 = V1 + `CachedIngredient`).
/// - V2 → V3: lightweight (V3 = V2 + `CachedComment` + `CachedRating`).
/// - V3 → V5: lightweight (V5 = V4 + `SyncedSavedRecipe`); the phantom V4 is
///   skipped — see the SchemaV4 / SchemaV5 headers. DUT-35 / DUT-6.
///
/// **SchemaV4 note (US-41 / T-702).** `SchemaV4` exists as a real
/// `VersionedSchema` in `SchemaV4.swift` and is the schema the
/// production `ModelContainer` uses — but it is intentionally NOT
/// registered in the migration plan because its `models` list is
/// byte-identical to V3's (same `@Model` class shapes). SwiftData
/// computes the schema fingerprint from the `@Model` class shape, not
/// the `versionIdentifier`, so registering both V3 and V4 in the
/// migration plan with identical model lists surfaces the "Duplicate
/// version checksums detected" runtime error at container open. The
/// V3 → V4 transition for existing v1.0 users is a no-op at the data
/// layer — the on-disk store opens cleanly under V4 because the
/// fingerprint matches V3's. The CloudKit-configuration switch that
/// makes V4 meaningful happens at the `ModelConfiguration` level (per
/// `RecipeStore+Containers.swift`'s opt-in gating), not at the
/// migration-plan level. **If a future PR adds an actual @Model field
/// change to V4** (e.g., the CL-90 `modifiedAt` LWW timestamp T-706
/// will need), the right pattern is to register V4 here as a
/// `MigrationStage.custom` and rename the new-field-bearing model
/// classes to typealiased names so the fingerprints diverge — see
/// the `SchemaV4.swift` header for the documented workaround.
///
/// **US-37 / CL-63 / T-640 note:** the `articleBodyHTML` optional
/// column on `CachedRecipe` was added via SwiftData's in-place
/// additive-optional migration path, NOT a separate schema stage —
/// new optional properties are accepted when the schema identifier
/// hasn't bumped.
///
/// Per MIGRATION.md rule 3 every stage has a paired migration test:
/// - `MigrationTests.lightweightV1toV2OpensCleanly`
/// - `MigrationV3Tests.V2_to_V3_lightweightMigration`
/// - `SchemaV4Tests.v3ToV4LightweightMigrationOpensCleanly` (the
///   no-op identity transition under the byte-identical-models
///   posture).
/// - `SchemaV5Tests.v3ToV5LightweightMigrationOpensCleanly` (additive
///   `SyncedSavedRecipe` entity, two-configuration split; DUT-35).
public enum MigrationPlan: SchemaMigrationPlan {

    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV5.self]
    }

    public static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
            // V3 -> V5 (DUT-35 / DUT-6): additive — adds `SyncedSavedRecipe`,
            // the single CloudKit-mirrored model. The phantom V4 (byte-identical
            // to V3) stays out of the chain to avoid the duplicate-checksum
            // trap; existing stores carry the V3/V4 fingerprint and land on V5
            // with one new entity and no data transform.
            .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV5.self),
        ]
    }
}
