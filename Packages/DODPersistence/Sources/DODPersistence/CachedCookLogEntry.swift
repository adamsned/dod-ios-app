import Foundation
import SwiftData

/// Local, private persistence of one "I made this" cook-journal entry
/// (US-48 / DUT-104) — the SwiftData mirror of ``DODSupport/CookLogEntry``.
///
/// **Local-only, never synced.** Like the six existing cache models, this row
/// lives only in the local store (`SchemaV6.localModels`, `cloudKitDatabase:
/// .none`) — the cook journal is private to the user and never leaves the
/// device (contrast the public comments/ratings). Only `SyncedSavedRecipe`
/// mirrors to CloudKit.
///
/// Stores **primitive fields only** (no `CookLogEntry` reference) so the
/// persistence schema stays independent of Support/Domain; conversion to the
/// pure value type happens in `RecipeStore` accessors (see
/// `RecipeStore+CookLog.swift`), the same pattern as `CachedComment` /
/// `CachedRating`.
///
/// Every attribute is optional-or-defaulted per DOD-CRASH-1 (defaults don't
/// change the schema hash; `init` overwrites them).
@Model
public final class CachedCookLogEntry {

    /// Stable id of the journal entry (matches `CookLogEntry.id`).
    public var id = UUID()
    /// WP post id of the recipe that was cooked.
    public var recipeID: Int = 0
    /// Snapshot of the recipe title at log time (so history reads correctly
    /// even if the recipe is later renamed or unpublished).
    public var recipeTitle = ""
    /// When it was cooked.
    public var cookedAt = Date.distantPast
    /// Optional private note ("used less salt next time").
    public var note: String?
    /// Optional private 1–5 self-rating (distinct from the public blog star).
    public var personalRating: Int?
    /// Optional local identifier for an attached photo (resolved by the photo
    /// store in a later slice).
    public var photoLocalID: String?

    public init(
        id: UUID,
        recipeID: Int,
        recipeTitle: String,
        cookedAt: Date,
        note: String? = nil,
        personalRating: Int? = nil,
        photoLocalID: String? = nil
    ) {
        self.id = id
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.cookedAt = cookedAt
        self.note = note
        self.personalRating = personalRating
        self.photoLocalID = photoLocalID
    }
}
