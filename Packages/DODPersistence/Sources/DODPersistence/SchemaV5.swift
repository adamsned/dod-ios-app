import Foundation
import SwiftData

/// Schema V5 — adds the `SyncedSavedRecipe` model and re-scopes CloudKit
/// mirroring (DUT-35 / DUT-6).
///
/// **What V5 changes vs V4.** Exactly one additive change: the new
/// `SyncedSavedRecipe` `@Model` is appended to the persistent model list. No
/// existing field on any of the six prior models is added, removed, or
/// renamed. That makes the V4 -> V5 transition a **lightweight** migration —
/// SwiftData creates the new entity's table at container open and leaves every
/// existing row untouched.
///
/// **The real point of V5: mirror scope.** V4 mirrored *all six* models to the
/// CloudKit private database, which mirrored the entire on-device cache —
/// including `CachedImage`'s photo blobs and the high-churn feed/ingredient
/// caches — and crashed Apple's mirror on the save-then-navigate path once the
/// Production schema went live (DUT-35). V5's production container splits the
/// schema across two `ModelConfiguration`s:
/// - a **local** configuration (`cloudKitDatabase: .none`) holding the six
///   existing cache models, which therefore never leave the device, and
/// - a **synced** configuration (`cloudKitDatabase: .private(...)` when the
///   opt-in flag is on) holding ONLY `SyncedSavedRecipe`.
/// So the only data that crosses devices is the small set of explicitly-saved
/// posts. See `RecipeStore+Containers.swift`.
///
/// **Migration-plan registration (vs the V4 phantom).** Unlike V4 — which was
/// byte-identical to V3 and therefore intentionally NOT registered in
/// `MigrationPlan` to avoid the "Duplicate version checksums detected" trap —
/// V5's model list differs from V3/V4 (it has the extra `SyncedSavedRecipe`
/// type), so its schema fingerprint is distinct and it is safe to register.
/// The migration stage is `.lightweight(fromVersion: SchemaV3.self,
/// toVersion: SchemaV5.self)`: existing v1.0 stores carry the V3/V4
/// fingerprint (the two are identical), so the chain V1 -> V2 -> V3 -> V5
/// lands them on V5 with one additive entity and no data transform. The
/// phantom V4 stays out of the chain by design.
///
/// **Per-store migration with the two-configuration split.** The existing
/// on-disk `default.store` is declared by V5's *local* configuration to hold
/// the six prior models, so its migration from the V3/V4 fingerprint is a
/// no-op at the data layer (same six class shapes); only its CloudKit flag
/// flips from `.private` to `.none`. The `SyncedSavedRecipe` rows live in a
/// separate, newly-created synced store, so introducing the entity never
/// rewrites `default.store`. A backfill (`RecipeStore.backfillSyncedSaved`)
/// seeds the synced store once from any existing `CachedRecipe.isSaved` rows.
public enum SchemaV5: VersionedSchema {

    public static var versionIdentifier: Schema.Version {
        Schema.Version(5, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        [
            CachedRecipe.self,
            CachedListPage.self,
            CachedImage.self,
            CachedIngredient.self,
            CachedComment.self,
            CachedRating.self,
            SyncedSavedRecipe.self,
        ]
    }

    /// The six local-only cache models — the *local* configuration's scope.
    /// Pinned here (rather than inlined in the container factory) so the
    /// schema source-of-truth and the configuration split can never drift.
    public static var localModels: [any PersistentModel.Type] {
        [
            CachedRecipe.self,
            CachedListPage.self,
            CachedImage.self,
            CachedIngredient.self,
            CachedComment.self,
            CachedRating.self,
        ]
    }

    /// The single synced model — the *synced* configuration's scope.
    public static var syncedModels: [any PersistentModel.Type] {
        [SyncedSavedRecipe.self]
    }
}
