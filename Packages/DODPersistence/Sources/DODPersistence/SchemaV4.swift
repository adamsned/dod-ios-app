import Foundation
import SwiftData

/// Schema V4 — Phase 15 schema-identity marker that gates the SwiftData →
/// CloudKit private-database mirror per [CL-86][cl-86] / [CL-88][cl-88] /
/// [CL-93][cl-93]. The production `ModelContainer` references V4's
/// `models` list; V4 is the schema source-of-truth post-T-702.
///
/// **What V4 changes vs V3.** The persistent model list is *identical*
/// — no fields are added, removed, or renamed on `CachedRecipe`,
/// `CachedListPage`, `CachedImage`, `CachedIngredient`, `CachedComment`,
/// or `CachedRating`. V4 exists purely to mark the boundary where the
/// production `ModelConfiguration(_:cloudKitDatabase:)` switches between
/// a plain SwiftData store (opt-out path) and a CloudKit-backed
/// `cloudKitDatabase: .private("iCloud.com.dutchovendaddy.DODApp")`
/// store (opt-in path). Apple's [Syncing model data across a person's
/// devices][apple-cloudkit] docs treat the CloudKit configuration as a
/// schema-identity change at the *configuration* layer — but SwiftData
/// computes the schema fingerprint from `@Model` class shapes, so
/// V4-with-identical-models has the same fingerprint as V3 at the
/// migration layer.
///
/// **Why no field changes.** Per CL-88, the synced scope is exactly the
/// existing `CachedRecipe` fields plus the relevant `CachedImage` rows;
/// the `modifiedAt` LWW resolution timestamp (CL-90) is added in a
/// *later* PR (T-706) when the conflict-resolution policy lands. T-702's
/// scope is the wiring + the schema-identity marker only; the
/// CloudKit-side records mirror the existing field set unchanged.
///
/// **Opt-in gating.** The `RecipeStore.productionContainer()` factory
/// reads the `dod.cloudkit.syncOptInV1` `UserDefaults` flag (default
/// `false`) and either constructs a CloudKit-backed `ModelConfiguration`
/// (when the user has opted in via T-704's first-launch sheet / T-703's
/// Settings toggle) or a plain SwiftData container (the AC-41.1 graceful
/// fallback when the user declined, hasn't been prompted, or isn't
/// signed into iCloud). Either path uses `SchemaV4.models` as the
/// source of truth — the choice is at the configuration layer, not the
/// schema layer.
///
/// **Migration-plan exclusion (intentional).** The `MigrationPlan` in
/// `SchemaV1.swift` does NOT register V4 because V4's `models` list is
/// byte-identical to V3's. SwiftData computes the schema checksum from
/// the `@Model` class shape; registering V3 + V4 with identical model
/// lists surfaces the "Duplicate version checksums detected" runtime
/// error at container open (the trap Spencer hit on the first SchemaV4
/// attempt during T-640). Production reads use `SchemaV4.models`; the
/// underlying on-disk schema fingerprint matches V3's, so existing v1.0
/// users open the V4 container cleanly with no migration step needed.
/// The V3 → V4 transition is a no-op at the data layer — the schema
/// identity is the same; what differs is which configuration the
/// container opens against.
///
/// **Cross-reference for the duplicate-checksum trap.** When a future
/// PR adds an actual `@Model` field change to V4 (e.g., the CL-90
/// `modifiedAt` LWW timestamp T-706 will need), the right pattern per
/// Apple's migration sample is to:
/// 1. Define the new-field-bearing class shape as a NESTED `@Model`
///    inside the `SchemaV4` enum (e.g., `SchemaV4.CachedRecipe`), NOT
///    as a redefinition of the top-level `CachedRecipe` class — the
///    nested class is a *distinct Swift type* with its own fingerprint
///    even when the field set is structurally similar.
/// 2. Update `SchemaV4.models` to reference the nested types.
/// 3. Register the V3 → V4 stage as `MigrationStage.custom` in
///    `MigrationPlan.stages` with a transform closure that copies V3
///    rows into V4 rows (since the Swift types differ, the rows are
///    structurally separate even when the field set overlaps).
/// 4. Refactor `RecipeStore` to reference the V4 model types via
///    typealias.
/// This is the documented Apple workaround when a schema needs to
/// diverge from a prior version *without* the additive-optional
/// in-place migration path being viable.
///
/// [cl-86]: ../../../specs/dod-ios-app/clarifications.md
/// [cl-88]: ../../../specs/dod-ios-app/clarifications.md
/// [cl-93]: ../../../specs/dod-ios-app/clarifications.md
/// [apple-cloudkit]: https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices
public enum SchemaV4: VersionedSchema {

    public static var versionIdentifier: Schema.Version {
        Schema.Version(4, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [
            CachedRecipe.self,
            CachedListPage.self,
            CachedImage.self,
            CachedIngredient.self,
            CachedComment.self,
            CachedRating.self,
        ]
    }
}
