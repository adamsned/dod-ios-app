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

| Version | When       | Change                                                                | Migration type | Locked by                                       |
| ------- | ---------- | --------------------------------------------------------------------- | -------------- | ----------------------------------------------- |
| V1 → V2 | 2026-05-23 | Added `CachedIngredient` model (local ingredient index for US-12).    | Lightweight    | `MigrationTests.lightweightV1toV2OpensCleanly`  |

**V2 design note.** No existing field on `CachedRecipe`/`CachedListPage`/`CachedImage` was touched. The new `CachedIngredient` rows start empty after upgrade; they fill in as recipes are viewed and `RecipeStore.mergeDetail(_:)` parses their JSON-LD. Search silently falls back to REST title/excerpt for recipes whose ingredients aren't yet indexed — there is no error path the user sees.
