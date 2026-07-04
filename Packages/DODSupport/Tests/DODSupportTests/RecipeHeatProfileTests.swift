import DODDomain
import Foundation
import Testing

@testable import DODSupport

/// L1 coverage for ``RecipeHeatProfile`` — the pure derivation of a recipe's
/// oven temperature + cooking task from its own free-text steps (DUT-551
/// Stream D / CL-306).
///
/// Every expectation pins a user-facing contract:
/// - the primary oven temp is the **max** explicit-unit °F across steps + title,
/// - a recipe with **no** explicit temperature returns `nil` (the confidence
///   gate — the caller hides the Heat Coach nudge rather than guessing),
/// - each ``CharcoalRecipeConverter/CookTask`` keyword branch maps correctly,
/// - a temp-present-but-no-keyword recipe falls back to `.bake`.
@Suite("RecipeHeatProfile (DUT-551 Stream D)") struct RecipeHeatProfileTests {

    // MARK: - Recipe fixture

    /// Build a minimal ``Recipe`` — only the fields ``RecipeHeatProfile``
    /// reads (title + instruction text) carry a signal; the rest are inert
    /// placeholders.
    /// A safe, non-optional stand-in URL for the fixture's `canonicalURL`
    /// (avoids a force-unwrap; ``RecipeHeatProfile`` never reads it).
    private static let fixtureURL = URL(fileURLWithPath: "/dev/null")

    private static func makeRecipe(
        title: String = "Test Recipe",
        steps: [String] = []
    ) -> Recipe {
        Recipe(
            id: 1,
            slug: "test-recipe",
            title: title,
            excerpt: "",
            canonicalURL: fixtureURL,
            publishedAt: Date(timeIntervalSince1970: 0),
            instructions: steps.enumerated().map { index, text in
                RecipeInstruction(step: index + 1, text: text)
            }
        )
    }

    // MARK: - Temperature: max across steps, nil when absent

    @Test func derivesMaxTemperatureFromSteps() {
        let recipe = Self.makeRecipe(
            title: "Dutch Oven Bread",
            steps: [
                "Preheat the oven to 375°F.",
                "Sear the crust briefly at 450°F, then lower to 350°F to finish.",
            ]
        )
        let derived = RecipeHeatProfile.derive(from: recipe)
        #expect(derived != nil)
        // Max explicit-unit temp across all steps.
        #expect(derived?.ovenTempF == 450)
    }

    @Test func picksUpTemperatureFromTitleToo() {
        let recipe = Self.makeRecipe(
            title: "425°F Skillet Cornbread",
            steps: ["Mix the batter and pour into the oven."]
        )
        #expect(RecipeHeatProfile.derive(from: recipe)?.ovenTempF == 425)
    }

    @Test func convertsCelsiusStepToFahrenheit() {
        // 175°C → 345°F (nearest-5 rounding via TemperatureConverter).
        let recipe = Self.makeRecipe(
            title: "Cobbler",
            steps: ["Bake at 175°C until golden."]
        )
        #expect(RecipeHeatProfile.derive(from: recipe)?.ovenTempF == 345)
    }

    @Test func returnsNilWhenNoTemperaturePresent() {
        // No explicit-unit temperature anywhere → not confident → nil.
        let recipe = Self.makeRecipe(
            title: "Simple Beans",
            steps: ["Bake at 350 for an hour.", "Stir in 2 cups of broth."]
        )
        #expect(RecipeHeatProfile.derive(from: recipe) == nil)
    }

    @Test func returnsNilForRecipeWithNoInstructionsOrTitleTemp() {
        #expect(RecipeHeatProfile.derive(from: Self.makeRecipe()) == nil)
    }

    // MARK: - Task inference — each keyword branch

    @Test func inferTaskMapsBakeKeywords() {
        for word in ["bread", "cake", "cobbler", "casserole", "biscuit", "bake"] {
            #expect(
                RecipeHeatProfile.inferTask(title: "Dutch oven \(word)", instructions: []) == .bake,
                "\(word) should map to .bake"
            )
        }
    }

    @Test func inferTaskMapsRoastKeywords() {
        #expect(RecipeHeatProfile.inferTask(title: "Sunday Roast", instructions: []) == .roast)
        #expect(
            RecipeHeatProfile.inferTask(title: "Whole Chicken Dinner", instructions: []) == .roast
        )
        #expect(RecipeHeatProfile.inferTask(title: "Herb Turkey", instructions: []) == .roast)
    }

    @Test func inferTaskMapsSimmerKeywords() {
        for word in ["stew", "beans", "chili", "soup", "simmer", "braise"] {
            #expect(
                RecipeHeatProfile.inferTask(title: "Camp \(word)", instructions: []) == .simmer,
                "\(word) should map to .simmer"
            )
        }
    }

    @Test func inferTaskMapsFryKeywords() {
        #expect(RecipeHeatProfile.inferTask(title: "Seared Steak", instructions: []) == .fry)
        #expect(RecipeHeatProfile.inferTask(title: "Fried Potatoes", instructions: []) == .fry)
    }

    @Test func inferTaskDefaultsToBakeWhenNoKeyword() {
        // Temp present, no method keyword → the lid-heavy baseline (.bake).
        #expect(RecipeHeatProfile.inferTask(title: "Grandma's Special", instructions: []) == .bake)
    }

    @Test func inferTaskReadsInstructionsNotJustTitle() {
        let task = RecipeHeatProfile.inferTask(
            title: "Weeknight Dinner",
            instructions: ["Let the pot simmer for two hours."]
        )
        #expect(task == .simmer)
    }

    // MARK: - Derive combines temp + task

    @Test func deriveReturnsTempAndInferredTask() {
        let recipe = Self.makeRecipe(
            title: "Dutch Oven Chili",
            steps: ["Brown the beef, then simmer at 300°F for two hours."]
        )
        #expect(RecipeHeatProfile.derive(from: recipe) == RecipeHeatProfile.Derived(ovenTempF: 300, task: .simmer))
    }
}
