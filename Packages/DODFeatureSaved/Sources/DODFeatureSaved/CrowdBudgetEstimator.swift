import DODDomain
import DODSupport
import Foundation

/// Rough dollars-and-cents estimate for feeding a crowd (DUT-997).
public enum CrowdBudgetEstimator {

    /// Rough USD cost of ONE ingredient row, by aisle.
    public static let costPerRow: [IngredientAisleClassifier.Aisle: Double] = [
        .produce: 1.0, .meat: 4.0, .dairy: 1.5,
        .pantry: 1.0, .spices: 0.5, .other: 1.0,
    ]

    public struct Estimate: Equatable, Sendable {
        public let totalCost: Double
        public let perPersonCost: Double
        public let scaleFactor: Double

        public init(totalCost: Double, perPersonCost: Double, scaleFactor: Double) {
            self.totalCost = totalCost
            self.perPersonCost = perPersonCost
            self.scaleFactor = scaleFactor
        }
    }

    /// Servings a recipe yields; falls back to 4 when nil or <= 0.
    public static func baseServings(for recipe: Recipe) -> Int {
        guard let servings = recipe.servings, servings > 0 else { return 4 }
        return servings
    }
}
