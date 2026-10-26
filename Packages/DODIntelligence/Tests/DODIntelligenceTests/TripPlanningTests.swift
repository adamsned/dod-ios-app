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

    @Test func fuelLedgerCalculatesBriquettesPerDay() {
        let ledger = makeFuelLedgerWithTestData()
        #expect(ledger.briquettesPerDay == [52, 24])
        #expect(ledger.totalBriquettes == 76)
        #expect(ledger.bags == 2)  // 76 briquettes with 40 per bag rounds up to 2 bags
    }

    @Test func fuelLedgerHandlesNoCharcoal() {
        let ledger = makeFuelLedgerWithNoCharcoal()
        #expect(ledger.briquettesPerDay == [0])
        #expect(ledger.totalBriquettes == 0)
        #expect(ledger.bags == 0)
    }

    @Test func fuelLedgerClampsDayBeyondDays() {
        let ledger = makeFuelLedgerWithClampedDay()
        #expect(ledger.briquettesPerDay == [0, 24])  // Should clamp to day 2 (index 1)
        #expect(ledger.totalBriquettes == 24)
        #expect(ledger.bags == 1)  // 24 briquettes with 40 per bag equals 1 bag
    }

    @Test func filtersByDietaryTags() {
        // Create test recipes with different dietary tags
        let recipes = makeTestRecipes()

        // Test: GlutenFreeDiet constraint keeps only recipes tagged GlutenFreeDiet
        let constraints = TripPlanConstraints(headcount: 4, dietaryTags: ["GlutenFreeDiet"])
        let candidates = TripCandidateFilter.candidates(from: recipes, constraints: constraints)
        #expect(candidates.count == 2)
        #expect(candidates.contains { $0.title == "Gluten Free Cake" })
        #expect(candidates.contains { $0.title == "Gluten Free Vegan Cake" })

        // Test: Empty tag list keeps all non-article recipes
        let emptyConstraints = TripPlanConstraints(headcount: 4, dietaryTags: [])
        let emptyCandidates = TripCandidateFilter.candidates(from: recipes, constraints: emptyConstraints)
        #expect(emptyCandidates.count == 4)  // All recipes except articles

        // Test: limit: 2 truncates to 2
        let limitedCandidates = TripCandidateFilter.candidates(from: recipes, constraints: constraints, limit: 2)
        #expect(limitedCandidates.count == 2)

        // Test: Articles are excluded
        testArticleExclusion(recipes: recipes, constraints: constraints)
    }

    // MARK: - Private helper methods

    private func makeTestRecipes() -> [Recipe] {
        [
            Recipe(
                id: 1,
                title: "Gluten Free Cake",
                suitableForDiet: ["GlutenFreeDiet"],
                ingredients: [],
                steps: [],
                prepTime: nil,
                cookTime: nil,
                totalTime: nil,
                difficulty: .easy,
                tags: []
            ),
            Recipe(
                id: 2,
                title: "Vegan Smoothie",
                suitableForDiet: ["VeganDiet"],
                ingredients: [],
                steps: [],
                prepTime: nil,
                cookTime: nil,
                totalTime: nil,
                difficulty: .easy,
                tags: []
            ),
            Recipe(
                id: 3,
                title: "Gluten Free Vegan Cake",
                suitableForDiet: ["GlutenFreeDiet", "VeganDiet"],
                ingredients: [],
                steps: [],
                prepTime: nil,
                cookTime: nil,
                totalTime: nil,
                difficulty: .easy,
                tags: []
            ),
            Recipe(
                id: 4,
                title: "Regular Cake",
                suitableForDiet: [],
                ingredients: [],
                steps: [],
                prepTime: nil,
                cookTime: nil,
                totalTime: nil,
                difficulty: .easy,
                tags: []
            ),
        ]
    }

    private func testArticleExclusion(recipes: [Recipe], constraints: TripPlanConstraints) {
        let articleRecipe = Recipe(
            id: 5,
            title: "Article",
            kind: .article,
            suitableForDiet: ["GlutenFreeDiet"],
            ingredients: [],
            steps: [],
            prepTime: nil,
            cookTime: nil,
            totalTime: nil,
            difficulty: .easy,
            tags: []
        )
        let withArticle = recipes + [articleRecipe]
        let candidatesWithArticle = TripCandidateFilter.candidates(from: withArticle, constraints: constraints)
        #expect(candidatesWithArticle.count == 2)  // Article should be excluded
    }
}
