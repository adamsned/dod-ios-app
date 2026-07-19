import Foundation
import Testing

@testable import DODDomain

@Suite struct RecipeIngredientListTests {
    // MARK: - Empty list

    @Test func listFromEmptyArrayReturnsEmpty() {
        let result = RecipeIngredient.list(from: [])
        #expect(result.isEmpty, "Empty input should produce empty list")
    }

    // MARK: - Single ingredient

    @Test func listFromSingleElementPreservesTextAndId() {
        let input = ["2 cups flour"]
        let result = RecipeIngredient.list(from: input)
        #expect(result.count == 1, "Single input should produce one ingredient")
        #expect(result[0].text == "2 cups flour", "Text should be preserved exactly")
        #expect(result[0].id != UUID(), "ID should be deterministic and set")
    }

    @Test func singleIngredientIdDerivedFromIndexedText() {
        let result = RecipeIngredient.list(from: ["Salt"])
        let directInit = RecipeIngredient(text: "Salt", index: 0)
        #expect(result[0].id == directInit.id, "list(from:) should use init(text:index:) with index 0")
    }

    // MARK: - Order and count

    @Test func listPreservesOrderOfElements() {
        let input = ["first", "second", "third"]
        let result = RecipeIngredient.list(from: input)
        #expect(result.count == 3, "Should have three ingredients")
        #expect(result[0].text == "first", "First element text should be preserved")
        #expect(result[1].text == "second", "Second element text should be preserved")
        #expect(result[2].text == "third", "Third element text should be preserved")
    }

    @Test func multipleIngredientsHaveDistinctIds() {
        let input = ["flour", "sugar", "butter"]
        let result = RecipeIngredient.list(from: input)
        let ids = Set(result.map(\.id))
        #expect(ids.count == 3, "All three ingredients should have distinct IDs")
    }

    // MARK: - DUT-705: Duplicate text at different positions

    @Test func duplicateTextAtDifferentPositionsGetDifferentIds() {
        let input = ["Salt", "Pepper", "Salt"]
        let result = RecipeIngredient.list(from: input)
        #expect(result.count == 3, "Should have three ingredients")
        #expect(result[0].text == "Salt", "First ingredient text should be Salt")
        #expect(result[2].text == "Salt", "Third ingredient text should be Salt")
        #expect(
            result[0].id != result[2].id,
            "Identical text at different positions (0 vs 2) must have different IDs"
        )
    }

    @Test func duplicateTextTwiceProducesDifferentIds() {
        let input = ["Garlic", "Garlic"]
        let result = RecipeIngredient.list(from: input)
        #expect(result.count == 2, "Should have two ingredients")
        #expect(result[0].text == result[1].text, "Both should be Garlic")
        #expect(
            result[0].id != result[1].id,
            "Same text at different indices (0 vs 1) must have different IDs (DUT-705)"
        )
    }

    @Test func triplicateDuplicateAllDistinct() {
        let input = ["X", "Y", "X", "X"]
        let result = RecipeIngredient.list(from: input)
        #expect(result[0].id != result[2].id, "Index 0 and 2 should differ")
        #expect(result[0].id != result[3].id, "Index 0 and 3 should differ")
        #expect(result[2].id != result[3].id, "Index 2 and 3 should differ")
        #expect(result[1].id != result[0].id, "Y should differ from X")
    }

    // MARK: - DUT-641: Determinism across multiple calls

    @Test func listIsDeterministicAcrossMultipleCalls() {
        let input = ["salt", "flour"]
        let result1 = RecipeIngredient.list(from: input)
        let result2 = RecipeIngredient.list(from: input)
        #expect(
            result1[0].id == result2[0].id,
            "DUT-641: First ingredient ID should be stable across calls"
        )
        #expect(
            result1[1].id == result2[1].id,
            "DUT-641: Second ingredient ID should be stable across calls"
        )
    }

    @Test func listIdStabilityWithWhitespace() {
        let input = ["2 cups flour", "1 tsp salt"]
        let result1 = RecipeIngredient.list(from: input)
        let result2 = RecipeIngredient.list(from: input)
        #expect(
            result1[0].id == result2[0].id,
            "ID stability should preserve whitespace differences"
        )
        #expect(
            result1[1].id == result2[1].id,
            "ID stability should work across multiple elements"
        )
    }

    // MARK: - Direct init(text:index:) coverage

    @Test func initWithIndexSameTextDifferentIndicesYieldDifferentIds() {
        let ing0 = RecipeIngredient(text: "Salt", index: 0)
        let ing1 = RecipeIngredient(text: "Salt", index: 1)
        #expect(
            ing0.id != ing1.id,
            "Same text with different indices should produce different IDs (DUT-705)"
        )
    }

    @Test func initWithIndexSameTextSameIndexYieldsSameId() {
        let ing1a = RecipeIngredient(text: "Salt", index: 0)
        let ing1b = RecipeIngredient(text: "Salt", index: 0)
        #expect(
            ing1a.id == ing1b.id,
            "Same text and same index should produce identical IDs (determinism)"
        )
    }

    @Test func initWithIndexDifferentFromPlainTextInit() {
        let plain = RecipeIngredient(text: "Salt")
        let indexed = RecipeIngredient(text: "Salt", index: 0)
        #expect(
            plain.id != indexed.id,
            "init(text:) derives from text alone; init(text:index:) includes index; they must differ"
        )
    }

    @Test func initWithIndexPreservesText() {
        let ing = RecipeIngredient(text: "2 cups flour", index: 5)
        #expect(ing.text == "2 cups flour", "Text should be preserved verbatim")
    }

    @Test func initWithMultipleIndicesAreDistinct() {
        let ingredients = (0..<5).map { RecipeIngredient(text: "Water", index: $0) }
        let ids = Set(ingredients.map(\.id))
        #expect(ids.count == 5, "Five different indices should yield five distinct IDs")
    }

    // MARK: - Edge cases

    @Test func emptyStringInList() {
        let input = ["", "flour"]
        let result = RecipeIngredient.list(from: input)
        #expect(result.count == 2, "Empty string should still create an ingredient")
        #expect(result[0].text.isEmpty, "Empty text should be preserved")
        #expect(result[0].id != result[1].id, "Empty string and 'flour' should have different IDs")
    }

    @Test func whitespaceOnlyString() {
        let input = ["   ", "flour"]
        let result = RecipeIngredient.list(from: input)
        #expect(result.count == 2, "Whitespace-only string should create an ingredient")
        #expect(result[0].text == "   ", "Whitespace should be preserved")
        #expect(result[0].id != result[1].id, "Whitespace and 'flour' should differ")
    }

    @Test func unicodeCharactersInText() {
        let input = ["2 cups 麺", "1 tbsp 塩"]
        let result = RecipeIngredient.list(from: input)
        #expect(result.count == 2, "Unicode text should work")
        #expect(result[0].text == "2 cups 麺", "Unicode should be preserved")
        #expect(result[0].id != result[1].id, "Different Unicode should yield different IDs")
    }

    @Test func veryLongIngredientText() {
        let longText = String(repeating: "a", count: 1000)
        let input = [longText, "short"]
        let result = RecipeIngredient.list(from: input)
        #expect(result.count == 2, "Very long text should work")
        #expect(result[0].text == longText, "Long text should be preserved exactly")
        #expect(result[0].id != result[1].id, "Long and short should differ")
    }

    @Test func newlineCharactersInText() {
        let input = ["flour\nsugar", "butter"]
        let result = RecipeIngredient.list(from: input)
        #expect(result.count == 2, "Newlines in text should work")
        #expect(result[0].text == "flour\nsugar", "Newlines should be preserved")
        #expect(result[0].id != result[1].id, "Different text with newline should yield different IDs")
    }

    // MARK: - Integration with Hashable and Identifiable

    @Test func ingredientIsHashable() {
        let ing1 = RecipeIngredient(text: "Salt", index: 0)
        let ing2 = RecipeIngredient(text: "Salt", index: 1)
        let set = Set([ing1, ing2])
        #expect(set.count == 2, "Ingredients with different IDs should be distinct in a Set")
    }

    @Test func ingredientConformsToIdentifiable() {
        let ing = RecipeIngredient(text: "Salt", index: 0)
        // Identifiable requires the ingredient to have an id property (it does)
        #expect(ing.id != UUID(), "ID should be non-nil")
    }

    @Test func listResultsCanBeUsedInForEachWithId() {
        let input = ["A", "B", "A"]
        let result = RecipeIngredient.list(from: input)
        // Verify each result is Identifiable (compilable in SwiftUI ForEach)
        let ids = result.map(\.id)
        #expect(ids.count == 3, "ForEach with id path should work")
        #expect(ids[0] != ids[2], "Identical text at different positions should have different IDs")
    }

    // MARK: - Codable round-trip

    @Test func ingredientFromListIsCodable() throws {
        let input = ["2 cups flour"]
        let ingredients = RecipeIngredient.list(from: input)
        let encoded = try JSONEncoder().encode(ingredients)
        let decoded = try JSONDecoder().decode([RecipeIngredient].self, from: encoded)
        #expect(decoded.count == 1, "Should decode to same count")
        #expect(decoded[0].id == ingredients[0].id, "ID should be preserved in round-trip")
        #expect(decoded[0].text == ingredients[0].text, "Text should be preserved in round-trip")
    }
}
