import Foundation

/// A user-created collection ("cookbook") that groups saved recipes under a
/// name, e.g. "Camping", "Thanksgiving", "Quick Weeknight" (DUT-105).
///
/// This is the pure value type the Saved tab renders and edits; its SwiftData
/// mirror is `DODPersistence.SyncedRecipeCollection`, the CloudKit-synced record
/// that actually persists (the same value-type/`@Model` split `Recipe` uses for
/// `SyncedSavedRecipe`).
///
/// **Membership is a plain id list.** A collection stores the WordPress post ids
/// of its recipes in ``recipeIDs`` rather than object references, mirroring the
/// synced store's deliberate "no `@Relationship`s, join by id" design (see
/// `SyncedSavedRecipe`). A recipe can appear in ``recipeIDs`` of more than one
/// collection, so a recipe lives in one or more collections at once (a
/// many-to-many, expressed as membership lists).
public struct RecipeCollection: Sendable, Hashable, Identifiable, Codable {

    /// Stable identity, minted on create and preserved across renames and
    /// devices (the CloudKit record key).
    public let id: UUID

    /// User-facing name shown on the shelf chip and the collection header.
    public let name: String

    /// Manual ordering position for the shelf, ascending. A freshly created
    /// collection is appended after the current maximum. Reordering rewrites
    /// these (nice-to-have, DUT-105).
    public let sortOrder: Int

    /// When the collection was created. Ties in ``sortOrder`` break by this,
    /// oldest first, so ordering is always deterministic.
    public let createdAt: Date

    /// The post ids of the recipes in this collection, in the order they were
    /// added. A subset of the user's saved recipes.
    public let recipeIDs: [Int]

    /// How many recipes the collection holds, for the shelf chip's count badge.
    public var recipeCount: Int { recipeIDs.count }

    public init(
        id: UUID,
        name: String,
        sortOrder: Int,
        createdAt: Date,
        recipeIDs: [Int]
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.recipeIDs = recipeIDs
    }
}
