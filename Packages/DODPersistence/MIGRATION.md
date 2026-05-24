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

**V2 design note.** No existing field on `CachedRecipe`/`CachedListPage`/`CachedImage` was touched. The new `CachedIngredient` rows start empty after upgrade; they fill in as recipes are viewed and `RecipeStore.mergeDetail(_:)` parses their JSON-LD. Search silently falls back to REST title/excerpt for recipes whose ingredients aren't yet indexed — there is no error path the user sees.

**V3 design note.** No existing field on the V2 models is touched — V3 adds two new model classes (`CachedComment`, `CachedRating`) and nothing else. The new tables start empty on first launch after upgrade; rows are populated lazily as the user opens recipes that have comments or ratings (`RecipeStore.cacheComments(_:)` / `RecipeStore.cacheRating(_:)`). Offline-read for comments (US-14 AC) returns an empty thread until at least one online fetch has populated the cache — same degradation pattern as the V2 ingredient index. The two `@Model` classes store **primitive fields only** (no `RecipeComment` / `RecipeRating` Domain references) so the persistence schema is independent of the Domain branch's merge order — conversion to Domain types is done by `RecipeStore` accessors via the `CachedCommentSnapshot` / `CachedRatingSnapshot` value types.
