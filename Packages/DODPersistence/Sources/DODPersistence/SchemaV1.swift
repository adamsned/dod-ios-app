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
/// - V5 → V6: lightweight (V6 = V5 + `CachedCookLogEntry`, the local-only
///   "I Made This" cook journal). DUT-104.
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
/// **DUT-572 / CL-310 note:** the four editorial columns on
/// `CachedRecipe` (`recipeCategory` / `recipeCuisine` /
/// `suitableForDiet` / `author`) follow the SAME `articleBodyHTML`
/// pattern — additive optional/defaulted attributes accepted via
/// SwiftData's in-place inference, NOT a new versioned schema. A
/// standalone `SchemaV7` was considered but rejected: it adds no new
/// entity, so its `@Model` class shapes are identical to V6's and
/// registering both trips the "Duplicate version checksums detected"
/// trap (the same trap that keeps the phantom V4 out of the plan —
/// see the SchemaV4 note above). Because `CachedRecipe`'s attributes
/// carry defaults (`[]` / nil), the fingerprint change is absorbed by
/// same-version inference and existing stores open cleanly with the
/// new columns defaulted.
///
/// Per MIGRATION.md rule 3 every stage has a paired migration test:
/// - `MigrationTests.lightweightV1toV2OpensCleanly`
/// - `MigrationV3Tests.V2_to_V3_lightweightMigration`
/// - `SchemaV4Tests.v3ToV4LightweightMigrationOpensCleanly` (the
///   no-op identity transition under the byte-identical-models
///   posture).
/// - `SchemaV5Tests.v3ToV5LightweightMigrationOpensCleanly` (additive
///   `SyncedSavedRecipe` entity, two-configuration split; DUT-35).
/// - `SchemaV6Tests.v5ToV6LightweightMigrationOpensCleanly` (additive
///   local-only `CachedCookLogEntry` cook journal; DUT-104).
/// - `SchemaV6Tests.recipeEditorialColumnsInferAdditively` (the four
///   DUT-572 / CL-310 `CachedRecipe` columns added via same-version
///   inference — no new schema stage; back-compat + round-trip proven).
public enum MigrationPlan: SchemaMigrationPlan {

    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV5.self, SchemaV6.self]
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
            // V5 -> V6 (DUT-104): additive — adds the local-only
            // `CachedCookLogEntry` cook-journal model. No existing field
            // changes; the new table starts empty and never mirrors to CloudKit.
            .lightweight(fromVersion: SchemaV5.self, toVersion: SchemaV6.self),
            // DUT-572 / CL-310: the four editorial `CachedRecipe` columns are
            // NOT a new stage — they're additive optional/defaulted attributes
            // absorbed by same-version inference (the `articleBodyHTML`
            // pattern). A SchemaV7 with no new entity would collide fingerprints
            // with V6 and trip "Duplicate version checksums detected"; see the
            // header note above.
        ]
    }
}
