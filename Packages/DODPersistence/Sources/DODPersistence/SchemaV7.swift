import Foundation
import SwiftData

/// Schema V7 — adds the `SyncedRecipeCollection` model, the second
/// CloudKit-mirrored record type, for recipe collections / cookbooks (DUT-105).
///
/// **Exactly one additive change vs V6:** the new `SyncedRecipeCollection`
/// `@Model` is appended to the model list (and to the *synced* scope). No
/// existing field on any prior model is added, removed, retyped, or made
/// required — in particular `SyncedSavedRecipe` is untouched (collection
/// membership is a plain `[Int]` id list on the new model, not a new inverse
/// relationship on the saved record). Its schema fingerprint therefore differs
/// from V6's by exactly one new entity, a **lightweight** migration: SwiftData
/// creates the new entity's table at container open and leaves every existing
/// row untouched. The new table starts empty; rows are written as the user
/// creates collections (`RecipeStore.createCollection`).
///
/// **Synced, like `SyncedSavedRecipe`.** `SyncedRecipeCollection` joins the
/// *synced* configuration (the named `"SyncedSaved"` store, which mirrors to the
/// CloudKit private DB when the user has opted in) so a user's cookbooks follow
/// them across devices, matching the saved set they organise. The six cache
/// models and the local-only cook journal stay in the *local* configuration
/// (`cloudKitDatabase: .none`). See `RecipeStore+Containers.swift`.
///
/// **Registered in `MigrationPlan` (vs the phantom V4 trap).** Because V7's
/// model list differs from V6's (it carries the extra
/// `SyncedRecipeCollection` type), its fingerprint is distinct, so — unlike the
/// byte-identical phantom V4 — it is safe to register. The stage is
/// `.lightweight(fromVersion: SchemaV6.self, toVersion: SchemaV7.self)`.
public enum SchemaV7: VersionedSchema {

    public static var versionIdentifier: Schema.Version {
        Schema.Version(7, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        SchemaV6.models + [SyncedRecipeCollection.self]
    }

    /// Unchanged from V6 — the seven local-only cache/journal models.
    public static var localModels: [any PersistentModel.Type] {
        SchemaV6.localModels
    }

    /// The synced models — now two, with recipe collections added alongside the
    /// saved set.
    public static var syncedModels: [any PersistentModel.Type] {
        SchemaV6.syncedModels + [SyncedRecipeCollection.self]
    }
}
