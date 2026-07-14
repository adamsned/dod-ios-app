import Foundation
import SwiftData

/// Schema V7 — adds the `SyncedProfile` model (DUT-943 Scope A: iOS ↔ iOS
/// profile sync — display name, email, avatar photo).
///
/// **Exactly one additive change vs V6:** the new `SyncedProfile` `@Model` is
/// appended to the persistent model list AND to the *synced* scope, alongside
/// `SyncedSavedRecipe`. No existing field on any prior model is added,
/// removed, or renamed, so V7's schema fingerprint differs from V6's by
/// exactly one new entity — a **lightweight** migration, exactly like the
/// V3 -> V5 (`SyncedSavedRecipe`) and V5 -> V6 (`CachedCookLogEntry`) stages
/// before it. SwiftData creates the new entity's table at container open and
/// leaves every existing row untouched.
///
/// **Second CloudKit-mirrored model (flag for review).** Until now
/// `SyncedSavedRecipe` was the ONLY model in `syncedModels` (DUT-35 locked
/// that down hard after the DOD-CRASH-1 over-broad-mirror incident).
/// `SyncedProfile` is a deliberate, narrow exception — a single small
/// per-user row (name/email/one avatar JPEG), not a cache — but it is still
/// the exact category DUT-35 warned about, so a schema/CloudKit reviewer
/// should re-confirm the CloudKit-clean invariants on `SyncedProfile` before
/// this ships (see `CloudKitSchemaCompatibilityTests`). It shares the SAME
/// named `"SyncedSaved"` store/configuration as `SyncedSavedRecipe` (see
/// `RecipeStore+Containers.swift`'s `syncedSavedConfiguration`) — no new
/// named store is introduced.
public enum SchemaV7: VersionedSchema {

    public static var versionIdentifier: Schema.Version {
        Schema.Version(7, 0, 0)
    }

    public static var models: [any PersistentModel.Type] {
        SchemaV6.models + [SyncedProfile.self]
    }

    /// Unchanged from V6 — `SyncedProfile` is synced, not local.
    public static var localModels: [any PersistentModel.Type] {
        SchemaV6.localModels
    }

    /// Now two models: `SyncedSavedRecipe` (DUT-35) + `SyncedProfile`
    /// (DUT-943 Scope A), both in the same `.private` configuration.
    public static var syncedModels: [any PersistentModel.Type] {
        SchemaV6.syncedModels + [SyncedProfile.self]
    }
}
