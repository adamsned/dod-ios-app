import DODSupport
import Testing

@testable import DODIntelligence

@Suite("FakeIntelligenceService.parseIngredient")
struct FakeIngredientParseTests {

    @Test func defaultReturnsCannedParse() async {
        let parse = await FakeIntelligenceService().parseIngredient("2 cups flour")
        #expect(parse?.item == "flour")
        #expect(parse?.quantity == 2)
    }

    @Test func unavailableReturnsNil() async {
        let parse = await FakeIntelligenceService(isAvailable: false).parseIngredient("2 cups flour")
        #expect(parse == nil)
    }

    @Test func nilCannedParseReturnsNil() async {
        let parse = await FakeIntelligenceService(ingredientParse: nil).parseIngredient("2 cups flour")
        #expect(parse == nil)
    }
}
