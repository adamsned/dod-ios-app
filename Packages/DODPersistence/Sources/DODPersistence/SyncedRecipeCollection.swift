import Foundation
import SwiftData

/// A user-created recipe collection ("cookbook") that groups saved recipes
/// under a name (DUT-105) — the SwiftData mirror of
/// ``DODDomain/RecipeCollection``.
///
/// **The second CloudKit-mirrored model (with `SyncedSavedRecipe`).** Like the
/// saved set, which posts a user has organised into which cookbooks needs to
/// cross devices, so this row lives in the same *synced* configuration
/// (`SchemaV7.syncedModels`, `cloudKitDatabase: .private(...)` when opted in).
/// The six cache models and the cook journal stay local-only. See
/// `RecipeStore+Containers.swift` for the two-configuration split.
///
/// **Membership by id list, no relationships (DUT-105).** A collection stores
/// the post ids of its recipes in ``recipeIDs`` rather than a SwiftData
/// `@Relationship` to `SyncedSavedRecipe`. This deliberately matches the synced
/// store's existing "join by a plain `Int` id, never a `@Relationship`" design
/// (see `SyncedSavedRecipe`'s header): it keeps the additive schema change from
/// touching `SyncedSavedRecipe` at all (no new inverse relationship on the
/// deployed synced record), and it sidesteps the CloudKit relationship rules.
/// A recipe id may appear in more than one collection's ``recipeIDs``, which is
/// exactly the many-to-many the ticket asks for. `[Int]` is a proven SwiftData
/// column here (`CachedRecipe.categoryIDs`) and a CloudKit-representable
/// scalar-array attribute.
///
/// **CloudKit-clean (DOD-CRASH-1 invariants).** Every stored attribute is
/// optional or carries a default value, there are no `@Attribute(.unique)`
/// constraints, and there are no `@Relationship`s — the same three hard
/// requirements `SyncedSavedRecipe` satisfies so the `.private` container opens.
/// `init` always overwrites the defaults; defaults are not part of the Core Data
/// version hash, so the additive V6 -> V7 migration that introduces this entity
/// stays lightweight.
@Model
public final class SyncedRecipeCollection {

    /// Stable collection identity, minted on create and preserved across renames
    /// and devices. Not `@Attribute(.unique)` (CloudKit forbids it); id lookups
    /// tolerate duplicates the same way `SyncedSavedRecipe`'s do.
    public var id = UUID()

    /// User-facing name shown on the shelf chip and collection header.
    public var name = ""

    /// Manual shelf ordering, ascending; a new collection is appended after the
    /// current maximum.
    public var sortOrder = 0

    /// When the collection was created — the deterministic tie-breaker for equal
    /// ``sortOrder`` values.
    public var createdAt = Date.distantPast

    /// The post ids of the recipes in this collection, in add order. A subset of
    /// the user's saved recipes.
    public var recipeIDs: [Int] = []

    public init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int,
        createdAt: Date = .now,
        recipeIDs: [Int] = []
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.recipeIDs = recipeIDs
    }
}
