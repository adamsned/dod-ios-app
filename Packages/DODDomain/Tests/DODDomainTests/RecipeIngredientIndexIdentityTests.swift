import Foundation
import Testing

@testable import DODDomain

@Suite("RecipeIngredient index-aware identity (DUT-705)") struct RecipeIngredientIndexIdentityTests {
    // DUT-705: init(text:index:) folds the positional index into the deterministic
    // hash, so the same ingredient line at different positions gets distinct ids.
    // This prevents duplicate lines from colliding on a single id when checked/
    // unchecked.

    @Test func sameTextAtDifferentIndicesYieldsDistinctIDs() {
        let saltAtIndex0 = RecipeIngredient(text: "Salt", index: 0)
        let saltAtIndex1 = RecipeIngredient(text: "Salt", index: 1)
        let saltAtIndex2 = RecipeIngredient(text: "Salt", index: 2)

        #expect(saltAtIndex0.id != saltAtIndex1.id, "Same text at different indices must have distinct ids")
        #expect(saltAtIndex0.id != saltAtIndex2.id)
        #expect(saltAtIndex1.id != saltAtIndex2.id)
    }

    @Test func sameTextIndexPairYieldsStableID() {
        let ingredient1 = RecipeIngredient(text: "Salt", index: 0)
        let ingredient2 = RecipeIngredient(text: "Salt", index: 0)

        #expect(ingredient1.id == ingredient2.id, "Same (text, index) pair must yield the same id across calls")
    }

    @Test func indexAwareInitDifferFromTextOnlyInit() {
        let textOnly = RecipeIngredient(text: "Salt")
        let indexAwareZero = RecipeIngredient(text: "Salt", index: 0)

        #expect(
            textOnly.id != indexAwareZero.id,
            "init(text:) and init(text:index:0) hash different inputs so ids differ"
        )
    }

    @Test func listFromDuplicateLinesYieldsDistinctIDs() {
        let lines = ["Salt", "Salt"]
        let ingredients = RecipeIngredient.list(from: lines)

        #expect(ingredients.count == 2)
        #expect(ingredients[0].text == "Salt")
        #expect(ingredients[1].text == "Salt")
        #expect(
            ingredients[0].id != ingredients[1].id,
            "Duplicate lines at different positions must have distinct ids via positional salting"
        )
    }

    @Test func listFromStableAcrossReparses() {
        let lines = ["Salt", "Pepper", "Salt"]

        let firstParse = RecipeIngredient.list(from: lines)
        let secondParse = RecipeIngredient.list(from: lines)

        #expect(firstParse.count == 3)
        #expect(secondParse.count == 3)

        // Core DUT-705 guarantee: calling list(from:) twice on the same input
        // yields the same ids pairwise.
        for index in firstParse.indices {
            #expect(
                firstParse[index].id == secondParse[index].id,
                "Reparse must yield stable ids at each position"
            )
        }
    }

    @Test func listFromPreservesTextVerbatim() {
        let lines = ["1 cup flour", "  2 tbsp salt  ", "3.5 oz vanilla extract"]
        let ingredients = RecipeIngredient.list(from: lines)

        #expect(ingredients.count == 3)
        #expect(ingredients[0].text == "1 cup flour")
        #expect(ingredients[1].text == "  2 tbsp salt  ")
        #expect(ingredients[2].text == "3.5 oz vanilla extract")
    }

    @Test func listFromPreservesOrder() {
        let lines = ["Flour", "Eggs", "Butter", "Sugar"]
        let ingredients = RecipeIngredient.list(from: lines)

        #expect(ingredients.count == 4)
        #expect(ingredients[0].text == "Flour")
        #expect(ingredients[1].text == "Eggs")
        #expect(ingredients[2].text == "Butter")
        #expect(ingredients[3].text == "Sugar")
    }

    @Test func listFromDistinctLinesYieldsDistinctIDs() {
        let lines = ["Salt", "Pepper", "Garlic"]
        let ingredients = RecipeIngredient.list(from: lines)

        #expect(ingredients.count == 3)
        let ids = Set(ingredients.map(\.id))
        #expect(ids.count == 3, "All distinct lines must yield distinct ids")
    }

    @Test func listFromEmptyInputYieldsEmptyList() {
        let ingredients = RecipeIngredient.list(from: [])

        #expect(ingredients.isEmpty)
    }

    @Test func explicitIDInitHonorsProvidedID() {
        let fixedID = UUID()
        let ingredient = RecipeIngredient(id: fixedID, text: "Salt")

        #expect(ingredient.id == fixedID, "Explicit init(id:text:) must honor the passed id")
        #expect(ingredient.text == "Salt")
    }

    @Test func explicitIDInitDoesNotRederive() {
        let fixedID = UUID()
        let ingredient1 = RecipeIngredient(id: fixedID, text: "Salt")
        let ingredient2 = RecipeIngredient(id: fixedID, text: "Salt")

        #expect(ingredient1.id == ingredient2.id)
        #expect(ingredient1.id == fixedID)
        #expect(ingredient2.id == fixedID)
    }
}
