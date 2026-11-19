import XCTest

@testable import DODFeatureProfile

final class HouseholdDietMatcherTests: XCTestCase {

    func testDairyIngredientTripsDairy() throws {
        let flags = Set<DietaryFlag>([.dairy])
        let ingredientTexts = ["2 tbsp butter"]
        let diets = [String]()

        let result = HouseholdDietMatcher.triggeredFlags(flags: flags, ingredientTexts: ingredientTexts, diets: diets)
        XCTAssertEqual(result, [.dairy])
    }

    func testUnflaggedIsIgnored() throws {
        let flags = Set<DietaryFlag>([.nuts])
        let ingredientTexts = ["1 cup milk"]
        let diets = [String]()

        let result = HouseholdDietMatcher.triggeredFlags(flags: flags, ingredientTexts: ingredientTexts, diets: diets)
        XCTAssertEqual(result, [])
    }

    func testGlutenFreeDietSuppressesGluten() throws {
        let flags = Set<DietaryFlag>([.gluten])
        let ingredientTexts = ["1 cup flour"]
        let diets = ["https://schema.org/GlutenFreeDiet"]

        let result = HouseholdDietMatcher.triggeredFlags(flags: flags, ingredientTexts: ingredientTexts, diets: diets)
        XCTAssertEqual(result, [])
    }

    func testEmptyFlagsIsEmpty() throws {
        let flags = Set<DietaryFlag>()
        let ingredientTexts = ["1 cup flour"]
        let diets = [String]()

        let result = HouseholdDietMatcher.triggeredFlags(flags: flags, ingredientTexts: ingredientTexts, diets: diets)
        XCTAssertEqual(result, [])
    }
}
