/// DUT-1000 — rolls per-meal charcoal recommendations into one trip total.
import Foundation

public enum CampFuelBudget {

    public struct MealFuel: Sendable, Equatable {
        public let mealID: UUID
        public let day: Int
        public let recipeTitle: String
        public let briquettes: Int
    }

    public struct Budget: Sendable, Equatable {
        public let perMeal: [MealFuel]  // in trip.sequencedMeals order
        public let totalBriquettes: Int
    }

    public static func budget(for trip: CampTrip) -> Budget {
        let perMeal = trip.sequencedMeals.map { meal -> MealFuel in
            let rec = CharcoalRecipeConverter.recommend(
                ovenTempF: meal.ovenTempF,
                ovenDiameterInches: meal.ovenDiameterInches,
                task: meal.task.cookTask
            )
            return MealFuel(
                mealID: meal.id,
                day: meal.day,
                recipeTitle: meal.recipeTitle,
                briquettes: rec.totalBriquettes
            )
        }
        return Budget(perMeal: perMeal, totalBriquettes: perMeal.reduce(0) { $0 + $1.briquettes })
    }
}
