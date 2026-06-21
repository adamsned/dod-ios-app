# Persistence Migration Discipline

**Why this file exists:** R-5 in [`plan.md §8`](../../specs/dod-ios-app/plan.md) — a future schema change could destroy users' saved recipes. This document is the discipline that prevents that.

## The rules

1. **Additive-only.** Never delete or rename a stored field on a `@Model`. Add a new optional field; let old reads return `nil`; backfill lazily when the row is next written.
2. **New schema version per breaking change.** If the addition cannot be expressed as a lightweight migration (e.g. semantics changed), bump to `SchemaV2` and add a `MigrationStage.custom` to `MigrationPlan.stages`.
3. **Tests required.** Every new `SchemaVN` lands with a migration test that creates a `SchemaV(N-1)` store, opens it under `SchemaVN`, and asserts the data is intact and re-readable.
4. **Never bypass with `try?` on `ModelContainer` init.** A failed migration must surface to the user as a launch error, not as a silently-empty database.

## How to add a new version

```swift
public enum SchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    public static var models: [any PersistentModel.Type] { [CachedRecipe.self, ...] }
}

public enum MigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    public static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
            // or .custom(...) if a transform is needed
        ]
    }
}
```

Then update `RecipeStore.makeContainer` to use `SchemaV2.self` and write a `MigrationTests.swift` that exercises the upgrade path.

## Live history

| Version | When       | Change                                                                                          | Migration type | Locked by                                          |
| ------- | ---------- | ----------------------------------------------------------------------------------------------- | -------------- | -------------------------------------------------- |
| V1 → V2 | 2026-05-23 | Added `CachedIngredient` model (local ingredient index for US-12).                              | Lightweight    | `MigrationTests.lightweightV1toV2OpensCleanly`     |
| V2 → V3 | 2026-05-24 | Added `CachedComment` + `CachedRating` models (comment + rating offline cache for US-13/US-14). | Lightweight    | `MigrationV3Tests.V2_to_V3_lightweightMigration`   |
| V3 → V4 | 2026-05-28 | Schema-identity marker for the SwiftData → CloudKit private-DB mirror (US-41 / CL-86 / CL-88 / CL-93 / T-702). No `@Model` field changes — V4's `models` list is identical to V3's. The marker exists purely to label the configuration boundary where `ModelConfiguration(cloudKitDatabase: .private(...))` takes over when the user opts in (`dod.cloudkit.syncOptInV1 = true`). **Intentionally NOT registered in the migration plan** — SwiftData computes the schema checksum from `@Model` class shapes, so V3 + V4 with identical models would trigger the "Duplicate version checksums detected" trap. Production reads use `SchemaV4.models`; existing v1.0 stores open cleanly under V4 via SwiftData's same-fingerprint inference. | No-op identity (not a migration plan stage) | `SchemaV4Tests.v3ToV4LightweightMigrationOpensCleanly` |
| V3 → V5 | 2026-06 | Added `SyncedSavedRecipe` model + the two-configuration CloudKit-scope split (DUT-35 / DUT-6); the phantom V4 stays out of the plan. | Lightweight | `SchemaV5Tests.v3ToV5LightweightMigrationOpensCleanly` |
| V5 → V6 | 2026-06-21 | Added `CachedCookLogEntry` model — the local-only "I Made This" cook journal (US-48 / DUT-104). Additive new table in the existing local `default.store`; starts empty, never mirrors to CloudKit. | Lightweight | `SchemaV6Tests.v5ToV6LightweightMigrationOpensCleanly` |

**V6 design note.** No existing field on any V5 model is touched — V6 adds exactly one new `@Model` class (`CachedCookLogEntry`) to the **local** configuration's scope (`SchemaV6.localModels`, `cloudKitDatabase: .none`). The cook journal is private to the device and never syncs (contrast `SyncedSavedRecipe`). The new table starts empty after upgrade and fills as the user logs cooks via `RecipeStore.logCook`. Primitive fields only (no `CookLogEntry` reference); conversion to the pure value type happens in `RecipeStore+CookLog.swift`, the same Cached*↔value pattern as comments/ratings.

**V2 design note.** No existing field on `CachedRecipe`/`CachedListPage`/`CachedImage` was touched. The new `CachedIngredient` rows start empty after upgrade; they fill in as recipes are viewed and `RecipeStore.mergeDetail(_:)` parses their JSON-LD. Search silently falls back to REST title/excerpt for recipes whose ingredients aren't yet indexed — there is no error path the user sees.

**V3 design note.** No existing field on the V2 models is touched — V3 adds two new model classes (`CachedComment`, `CachedRating`) and nothing else. The new tables start empty on first launch after upgrade; rows are populated lazily as the user opens recipes that have comments or ratings (`RecipeStore.cacheComments(_:)` / `RecipeStore.cacheRating(_:)`). Offline-read for comments (US-14 AC) returns an empty thread until at least one online fetch has populated the cache — same degradation pattern as the V2 ingredient index. The two `@Model` classes store **primitive fields only** (no `RecipeComment` / `RecipeRating` Domain references) so the persistence schema is independent of the Domain branch's merge order — conversion to Domain types is done by `RecipeStore` accessors via the `CachedCommentSnapshot` / `CachedRatingSnapshot` value types.

**V4 design note (Phase 15: CloudKit sync — US-41 / CL-86..CL-99 / T-702).** No existing field on the V3 models is touched. V4's `models` list is byte-identical to V3's — every `@Model` class shape is unchanged. The schema-identity marker exists *only* to label the boundary where the production `ModelConfiguration` switches between a plain SwiftData store (opt-out path) and a CloudKit-backed `cloudKitDatabase: .private("iCloud.com.dutchovendaddy.DODApp")` store (opt-in path). Apple's "Syncing model data across a person's devices" docs treat the CloudKit configuration as a schema-identity change *at the configuration layer* — but SwiftData computes the schema fingerprint from `@Model` class shapes, so V4-with-identical-models has the same fingerprint as V3 at the migration layer. **V4 is therefore intentionally NOT registered in `MigrationPlan.schemas`** — the on-the-first-attempt iteration that registered V3 + V4 simultaneously failed at container open with `SwiftDataError._Error.loadIssueModelContainer` because the duplicate fingerprints can't be distinguished by the migration plan's stage resolver. The production `ModelContainer` reads `SchemaV4.models` (the source of truth post-T-702); SwiftData's same-fingerprint inference handles the V3 → V4 no-op transition transparently for existing v1.0 users — the on-disk store opens cleanly with no rewriting. The CL-90 `modifiedAt` field that the T-706 conflict-resolution policy needs is **not** added here — it lands as a future additive optional column under SwiftData's default schema-inference migration path the same way `articleBodyHTML` did (the T-640 follow-up's note above stays in force). **Backward compatibility** is locked by AC-41.11: existing v1.0 users keep working unchanged because the opt-in flag defaults to `false` — the V3 → V4 schema-identity change is a no-op at the data layer, and the configuration stays plain-SwiftData until the user explicitly opts in via T-703's Settings toggle or T-704's first-launch sheet. **Future-work follow-up.** When a PR ships an actual `@Model` field change to V4 (e.g., the CL-90 `modifiedAt` LWW timestamp), the documented Apple workaround per the `SchemaV4.swift` header is to nest distinct `@Model` classes inside `SchemaV4` (e.g., `SchemaV4.CachedRecipe`), register V4 in `MigrationPlan.schemas`, register the V3 → V4 stage as `MigrationStage.custom` with a transform closure, and refactor `RecipeStore` to reference the V4 model types via typealias.
