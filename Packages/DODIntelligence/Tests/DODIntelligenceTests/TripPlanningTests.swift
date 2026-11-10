import DODDomain
import DODSupport
import Foundation
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
        let recipe = makeRecipe(id: 1, title: "Test Recipe", servings: 4, steps: ["bake at 350°F"])

        let constraints = TripPlanConstraints(headcount: 8, days: 1, mealsPerDay: 1, ovenDiameterInches: 12)
        let slot = TripSlotBuilder.makeSlot(day: 1, meal: 1, recipe: recipe, constraints: constraints)

        #expect(slot.scaleFactor == 2.0)
        #expect(slot.charcoal?.totalBriquettes == 24)
    }

    @Test func makesSlotWithNilCharcoalWhenNoTemperature() {
        // Recipe with no temperature should give charcoal == nil
        let recipe = makeRecipe(id: 1, title: "Test Recipe", servings: 4, steps: ["mix ingredients"])

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
            makeRecipe(id: 1, title: "Gluten Free Cake", diet: ["GlutenFreeDiet"]),
            makeRecipe(id: 2, title: "Vegan Smoothie", diet: ["VeganDiet"]),
            makeRecipe(id: 3, title: "Gluten Free Vegan Cake", diet: ["GlutenFreeDiet", "VeganDiet"]),
            makeRecipe(id: 4, title: "Regular Cake", diet: []),
        ]
    }

    private func testArticleExclusion(recipes: [Recipe], constraints: TripPlanConstraints) {
        let articleRecipe = makeRecipe(id: 5, title: "Article", kind: .article, diet: ["GlutenFreeDiet"])
        let withArticle = recipes + [articleRecipe]
        let candidatesWithArticle = TripCandidateFilter.candidates(from: withArticle, constraints: constraints)
        #expect(candidatesWithArticle.count == 2)  // Article should be excluded
    }

    @Test func estimateTokens() {
        #expect(TripTokenBudget.estimateTokens("abcdefgh") == 2)
    }

    @Test func needsEscalationWithShortCandidates() {
        // With 3 short candidates and `slotCount: 2`, `needsEscalation` is false.
        let recipes = [
            makeRecipe(id: 1, title: "A"),
            makeRecipe(id: 2, title: "B"),
            makeRecipe(id: 3, title: "C"),
        ]
        #expect(!TripTokenBudget.needsEscalation(candidates: recipes, slotCount: 2))
    }

    @Test func needsEscalationWithLargeSlotCount() {
        // With `slotCount: 400`, `needsEscalation` is true.
        let recipes = [
            makeRecipe(id: 1, title: "A")
        ]
        #expect(TripTokenBudget.needsEscalation(candidates: recipes, slotCount: 400))
    }

    @Test func needsEscalationWithManyLongCandidates() {
        // With 200 candidates carrying very long titles and `slotCount: 1`, `needsEscalation` is true.
        let recipes = Array(
            repeating: makeRecipe(id: 1, title: String(repeating: "A", count: 100)),
            count: 200
        )
        #expect(TripTokenBudget.needsEscalation(candidates: recipes, slotCount: 1))
    }

    // MARK: - Fixtures

    private func makeRecipe(
        id: Int,
        title: String,
        servings: Int? = nil,
        steps: [String] = [],
        kind: PostKind = .recipe,
        diet: [String] = []
    ) -> Recipe {
        Recipe(
            id: id,
            slug: "recipe-\(id)",
            title: title,
            excerpt: "",
            canonicalURL: URL(fileURLWithPath: "/recipes/\(id)"),
            publishedAt: Date(timeIntervalSince1970: 0),
            instructions: steps.enumerated().map { RecipeInstruction(step: $0.offset + 1, text: $0.element) },
            servings: servings,
            kind: kind,
            suitableForDiet: diet
        )
    }

    private func slot(day: Int, briquettes: Int?) -> TripMealSlot {
        TripMealSlot(
            day: day,
            meal: 1,
            recipeID: day,
            recipeTitle: "R",
            servings: 4,
            scaleFactor: 1,
            charcoal: briquettes.map {
                CharcoalRecommendation(
                    totalBriquettes: $0,
                    bottom: $0 / 3,
                    top: $0 - $0 / 3,
                    refreshIntervalMinutes: 45
                )
            }
        )
    }

    private func makeFuelLedgerWithTestData() -> TripFuelLedger {
        let slots = [
            slot(day: 1, briquettes: 24),
            slot(day: 1, briquettes: 28),
            slot(day: 2, briquettes: 24),
        ]
        return TripFuelLedger(plan: TripPlan(slots: slots), days: 2)
    }

    private func makeFuelLedgerWithNoCharcoal() -> TripFuelLedger {
        TripFuelLedger(plan: TripPlan(slots: [slot(day: 1, briquettes: nil)]), days: 1)
    }

    private func makeFuelLedgerWithClampedDay() -> TripFuelLedger {
        TripFuelLedger(plan: TripPlan(slots: [slot(day: 5, briquettes: 24)]), days: 2)
    }
}
