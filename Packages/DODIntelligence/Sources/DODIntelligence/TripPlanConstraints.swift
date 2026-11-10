import Foundation

/// DUT-1031 — what the cook told us about the gathering or trip. Plain and FoundationModels-free.
public struct TripPlanConstraints: Sendable, Equatable {
    public let headcount: Int
    public let dietaryTags: [String]  // matches Recipe.suitableForDiet, e.g. "GlutenFreeDiet"
    public let days: Int  // 1 = single-event Host Mode
    public let mealsPerDay: Int
    public let ovenDiameterInches: Int

    public init(
        headcount: Int,
        dietaryTags: [String] = [],
        days: Int = 1,
        mealsPerDay: Int = 1,
        ovenDiameterInches: Int = 12
    ) {
        self.headcount = max(1, headcount)
        self.dietaryTags = dietaryTags
        self.days = max(1, days)
        self.mealsPerDay = max(1, mealsPerDay)
        self.ovenDiameterInches = max(1, ovenDiameterInches)
    }

    /// One slot per meal: days × mealsPerDay.
    public var slotCount: Int { days * mealsPerDay }
}
