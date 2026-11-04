import DODSupport
import Foundation

/// One meal slot: which in-corpus recipe, scaled to how many servings.
public struct TripMealSlot: Sendable, Equatable {
    public let day: Int  // 1-based
    public let meal: Int  // 1-based within the day
    public let recipeID: Int  // Recipe.id from RecipeStore
    public let recipeTitle: String
    public let servings: Int  // headcount-scaled target
    public let scaleFactor: Double  // servings / source yield, from deterministic code
    public let charcoal: CharcoalRecommendation?  // nil when no temperature could be derived

    public init(
        day: Int,
        meal: Int,
        recipeID: Int,
        recipeTitle: String,
        servings: Int,
        scaleFactor: Double,
        charcoal: CharcoalRecommendation?
    ) {
        self.day = day
        self.meal = meal
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.servings = servings
        self.scaleFactor = scaleFactor
        self.charcoal = charcoal
    }
}

public struct TripPlan: Sendable, Equatable {
    public let slots: [TripMealSlot]
    /// Sum of CharcoalRecommendation.totalBriquettes across slots.
    public var totalBriquettes: Int { slots.compactMap(\.charcoal).reduce(0) { $0 + $1.totalBriquettes } }
    /// Set by the token-budget check (ticket 6) when the plan should go to Private Cloud Compute.
    public let needsEscalation: Bool

    public init(slots: [TripMealSlot], needsEscalation: Bool = false) {
        self.slots = slots
        self.needsEscalation = needsEscalation
    }
}
