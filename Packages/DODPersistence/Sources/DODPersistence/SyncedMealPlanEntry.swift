import Foundation
import SwiftData

/// DUT-103 — one recipe assigned to a (day, meal slot). Mirrors to CloudKit
/// like `SyncedSavedRecipe`. CloudKit-clean: defaults on every attribute, no
/// unique constraints, no relationships.
@Model
public final class SyncedMealPlanEntry {
    /// Stable identity (CloudKit can't enforce uniqueness, so dedupe by this).
    public var entryID = UUID()
    /// WordPress post id of the planned recipe.
    public var recipeID: Int = 0
    /// Display fields so the week view renders offline / on another device.
    public var recipeTitle: String = ""
    public var heroImageURLString: String?
    /// Start-of-day of the planned date.
    public var day = Date.distantPast
    /// `MealSlot.rawValue` (stored as String for CloudKit friendliness).
    public var slotRaw: String = "dinner"
    public var createdAt = Date.distantPast

    public init(
        entryID: UUID = UUID(),
        recipeID: Int,
        recipeTitle: String,
        heroImageURLString: String? = nil,
        day: Date,
        slotRaw: String,
        createdAt: Date = .now
    ) {
        self.entryID = entryID
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.heroImageURLString = heroImageURLString
        self.day = day
        self.slotRaw = slotRaw
        self.createdAt = createdAt
    }
}
