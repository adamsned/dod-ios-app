import DODDomain
import Foundation

public struct DietEvaluation: Sendable, Equatable {
    /// Flagged allergens found in the ingredient text.
    public let allergenHits: Set<Allergen>
    /// True when every selected pattern is affirmed by `suitableForDiet` or by no violating ingredient.
    public let fitsDiet: Bool
    /// True when the recipe has no ingredient data, so no safety claim can be made.
    public let isIncomplete: Bool
}