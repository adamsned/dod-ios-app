import Foundation
import SwiftData

/// Schema V6 — adds the local-only `CachedCookLogEntry` cook-journal model
/// (US-48 / DUT-104, the "I Made This" journal).
///
/// **Exactly one additive change vs V5:** the new `CachedCookLogEntry` `@Model`
/// is appended to the model list (and to the *local* scope). No existing field
/// on any prior model is added, removed, or renamed, so its schema fingerprint
/// differs from V5's by exactly one new entity — a **lightweight** migration.
/// SwiftData creates the new entity's table at container open and leaves every
/// existing row untouched. The new table starts empty; rows are written as the
/// user logs cooks (`RecipeStore.logCook`).
///
/// **Local-only, like the six cache models.** `CachedCookLogEntry` belongs to
/// the *local* configuration (`cloudKitDatabase: .none`) — the cook journal is
/// private to the device and never mirrors to CloudKit. `SyncedSavedRecipe`
/// remains the only synced model. Because the new entity lives in the existing
/// unnamed `default.store` (the local configuration), the V5 -> V6 transition
/// adds a table to that store without rewriting any existing rows.
public enum SchemaV6: VersionedSchema {

    public static var versionIdentifier: Schema.Version {
        Schema.Version(6, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        SchemaV5.models + [CachedCookLogEntry.self]
    }

    /// The local-only cache models — now seven, with the cook journal added.
    public static var localModels: [any PersistentModel.Type] {
        SchemaV5.localModels + [CachedCookLogEntry.self]
    }

    /// Unchanged from V5 — only `SyncedSavedRecipe` syncs.
    public static var syncedModels: [any PersistentModel.Type] {
        SchemaV5.syncedModels
    }
}
