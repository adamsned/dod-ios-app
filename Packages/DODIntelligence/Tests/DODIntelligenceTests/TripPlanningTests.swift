import DODSupport
import Testing

@testable import DODIntelligence

@Suite("TripPlanning")
struct TripPlanningTests {
    @Test func slotCountIsDaysTimesMeals() {
        #expect(TripPlanConstraints(headcount: 6, days: 3, mealsPerDay: 2).slotCount == 6)
    }
    @Test func clampsNonPositiveInputs() {
        let constraints = TripPlanConstraints(headcount: 0, days: 0, mealsPerDay: -1)
        #expect(constraints.headcount == 1 && constraints.slotCount == 1)
    }
    @Test func totalBriquettesSumsSlotsAndSkipsNil() {
        let charcoalRecommendation = CharcoalRecommendation(
            totalBriquettes: 24,
            bottom: 8,
            top: 16,
            refreshIntervalMinutes: 45
        )
        let plan = TripPlan(slots: [
            TripMealSlot(
                day: 1,
                meal: 1,
                recipeID: 1,
                recipeTitle: "A",
                servings: 4,
                scaleFactor: 1,
                charcoal: charcoalRecommendation
            ),
            TripMealSlot(day: 1, meal: 2, recipeID: 2, recipeTitle: "B", servings: 4, scaleFactor: 1, charcoal: nil),
            TripMealSlot(
                day: 2,
                meal: 1,
                recipeID: 3,
                recipeTitle: "C",
                servings: 4,
                scaleFactor: 1,
                charcoal: charcoalRecommendation
            ),
        ])
        #expect(plan.totalBriquettes == 48)
    }

    @Test func makesSlotWithScalingAndCharcoal() {
        // Recipe with servings: 4, a step saying "bake at 350°F", and headcount 8
        // should give scaleFactor == 2.0 and charcoal?.totalBriquettes == 24 for a 12" oven
        let recipe = Recipe(
            id: 1,
            title: "Test Recipe",
            servings: 4,
            steps: [
                RecipeStep(
                    text: "bake at 350°F",
                    duration: nil,
                    temperature: nil,
                    equipment: nil
                )
            ],
            ingredients: [],
            prepTime: nil,
            cookTime: nil,
            totalTime: nil,
            difficulty: .easy,
            tags: []
        )

        let constraints = TripPlanConstraints(headcount: 8, days: 1, mealsPerDay: 1, ovenDiameterInches: 12)
        let slot = TripSlotBuilder.makeSlot(day: 1, meal: 1, recipe: recipe, constraints: constraints)

        #expect(slot.scaleFactor == 2.0)
        #expect(slot.charcoal?.totalBriquettes == 24)
    }

    @Test func makesSlotWithNilCharcoalWhenNoTemperature() {
        // Recipe with no temperature should give charcoal == nil
        let recipe = Recipe(
            id: 1,
            title: "Test Recipe",
            servings: 4,
            steps: [
                RecipeStep(
                    text: "mix ingredients",
                    duration: nil,
                    temperature: nil,
                    equipment: nil
                )
            ],
            ingredients: [],
            prepTime: nil,
            cookTime: nil,
            totalTime: nil,
            difficulty: .easy,
            tags: []
        )

        let constraints = TripPlanConstraints(headcount: 8, days: 1, mealsPerDay: 1, ovenDiameterInches: 12)
        let slot = TripSlotBuilder.makeSlot(day: 1, meal: 1, recipe: recipe, constraints: constraints)

        #expect(slot.charcoal == nil)
    }
}
