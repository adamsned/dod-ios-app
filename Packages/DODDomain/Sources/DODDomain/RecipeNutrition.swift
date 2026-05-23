import Foundation

/// Nutrition facts from JSON-LD `NutritionInformation`.
/// Stored as strings (not Doubles) because JSON-LD values carry units like
/// "12g" and "200 kcal" inline; preserving the original string avoids
/// information loss across the round trip.
/// Spec trace: spec.md AC-4.1 (meta row), plan.md §2.
public struct RecipeNutrition: Sendable, Hashable, Codable {
    public let calories: String?
    public let servingSize: String?
    public let proteinGrams: String?
    public let carbsGrams: String?
    public let fatGrams: String?

    public init(
        calories: String? = nil,
        servingSize: String? = nil,
        proteinGrams: String? = nil,
        carbsGrams: String? = nil,
        fatGrams: String? = nil
    ) {
        self.calories = calories
        self.servingSize = servingSize
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
    }
}
