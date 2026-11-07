import Testing

@testable import DODIntelligence

@Suite("LiveDODIntelligenceService ingredient parsing")
struct IngredientListParsingTests {

    @Test func parseIngredientListSplitsAndCleans() {
        let parsed = LiveDODIntelligenceService.parseIngredientList("Eggs, cheddar\n spinach, EGGS")
        #expect(parsed == ["eggs", "cheddar", "spinach"])
    }

    @Test func parseIngredientListEmptyInput() {
        #expect(LiveDODIntelligenceService.parseIngredientList("").isEmpty)
    }
}
