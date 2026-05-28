import Foundation
import Testing

@testable import DODSupport

/// Golden L1 coverage for ``IngredientAisleClassifier``.
///
/// Spec trace: US-39 / AC-39.4 (aisle grouping), AC-39.12 (pure on-device).
/// CL-67 (static keyword-map strategy), CL-79 (logic-core split). Constitution
/// §6 L1 mandate — every domain transform owns named tests.
///
/// Cases sampled to mirror real dutchovendaddy.com JSON-LD `recipeIngredient`
/// wording: leading quantities, units, and trailing `, diced`-style
/// qualifiers all surround the keyword the classifier must find.
@Suite("IngredientAisleClassifier")
struct IngredientAisleClassifierTests {

    private typealias Aisle = IngredientAisleClassifier.Aisle

    // MARK: - Produce

    @Test func dicedYellowOnionIsProduce() {
        #expect(IngredientAisleClassifier.classify("2 cups diced yellow onion") == .produce)
    }

    @Test func freshGarlicIsProduce() {
        #expect(IngredientAisleClassifier.classify("3 cloves garlic, minced") == .produce)
    }

    @Test func tomatoIsProduce() {
        #expect(IngredientAisleClassifier.classify("1 large tomato, chopped") == .produce)
    }

    @Test func freshBasilIsProduce() {
        #expect(IngredientAisleClassifier.classify("1/4 cup fresh basil leaves") == .produce)
    }

    @Test func bellPepperIsProduce() {
        #expect(IngredientAisleClassifier.classify("1 red bell pepper, sliced") == .produce)
    }

    // MARK: - Meat & Seafood

    @Test func chickenThighsAreMeat() {
        #expect(
            IngredientAisleClassifier.classify("1 ½ pounds boneless skinless chicken thighs")
                == .meat
        )
    }

    @Test func groundBeefIsMeat() {
        #expect(IngredientAisleClassifier.classify("1 lb ground beef, 80/20") == .meat)
    }

    @Test func baconIsMeat() {
        #expect(IngredientAisleClassifier.classify("6 slices thick-cut bacon") == .meat)
    }

    @Test func salmonIsMeat() {
        #expect(IngredientAisleClassifier.classify("4 salmon fillets") == .meat)
    }

    // MARK: - Dairy

    @Test func milkIsDairy() {
        #expect(IngredientAisleClassifier.classify("2 cups whole milk") == .dairy)
    }

    @Test func butterIsDairy() {
        #expect(IngredientAisleClassifier.classify("4 tablespoons unsalted butter") == .dairy)
    }

    @Test func eggsAreDairy() {
        #expect(IngredientAisleClassifier.classify("2 large eggs") == .dairy)
    }

    @Test func cheddarIsDairy() {
        #expect(IngredientAisleClassifier.classify("1 cup shredded cheddar cheese") == .dairy)
    }

    // MARK: - Pantry

    @Test func allPurposeFlourIsPantry() {
        #expect(IngredientAisleClassifier.classify("2 cups all-purpose flour") == .pantry)
    }

    @Test func oliveOilIsPantry() {
        #expect(IngredientAisleClassifier.classify("3 tablespoons extra virgin olive oil") == .pantry)
    }

    @Test func vanillaExtractIsPantry() {
        #expect(IngredientAisleClassifier.classify("1 tsp vanilla extract") == .pantry)
    }

    @Test func tomatoPasteIsPantryNotProduce() {
        // "tomato paste" must beat the bare "tomato" → produce keyword.
        #expect(IngredientAisleClassifier.classify("2 tablespoons tomato paste") == .pantry)
    }

    @Test func riceIsPantry() {
        #expect(IngredientAisleClassifier.classify("1 cup long-grain white rice") == .pantry)
    }

    // MARK: - Spices

    @Test func smokedPaprikaIsSpices() {
        #expect(IngredientAisleClassifier.classify("1 tsp smoked paprika") == .spices)
    }

    @Test func groundCuminIsSpices() {
        #expect(IngredientAisleClassifier.classify("½ teaspoon ground cumin") == .spices)
    }

    @Test func saltIsSpices() {
        #expect(IngredientAisleClassifier.classify("1 tsp kosher salt") == .spices)
    }

    @Test func garlicPowderIsSpicesNotProduce() {
        // "garlic powder" must beat the bare "garlic" → produce keyword.
        #expect(IngredientAisleClassifier.classify("1 tablespoon garlic powder") == .spices)
    }

    @Test func blackPepperIsSpices() {
        #expect(IngredientAisleClassifier.classify("freshly ground black pepper") == .spices)
    }

    // MARK: - Other (fallback)

    @Test func unknownBrandShorteningIsOther() {
        // "vegetable shortening" carries no mapped stem ("vegetable oil"
        // requires "oil", which "shortening" is not) → documented miss.
        #expect(IngredientAisleClassifier.classify("1 packet vegetable shortening") == .other)
    }

    @Test func trulyUnmatchedIsOther() {
        #expect(IngredientAisleClassifier.classify("1 cup chayote, peeled") == .other)
    }

    @Test func emptyStringIsOther() {
        #expect(IngredientAisleClassifier.classify("") == .other)
    }

    @Test func whitespaceOnlyIsOther() {
        #expect(IngredientAisleClassifier.classify("   ") == .other)
    }

    @Test func noKeywordToTasteIsOther() {
        #expect(IngredientAisleClassifier.classify("a pinch of saffron threads, to taste") == .other)
    }

    // MARK: - Case insensitivity

    @Test func uppercaseOnionMatches() {
        #expect(IngredientAisleClassifier.classify("DICED YELLOW ONION") == .produce)
    }

    @Test func mixedCaseChickenMatches() {
        #expect(IngredientAisleClassifier.classify("Boneless ChIcKeN Breast") == .meat)
    }

    @Test func titleCaseFlourMatches() {
        #expect(IngredientAisleClassifier.classify("All-Purpose Flour") == .pantry)
    }

    // MARK: - Enum completeness

    /// Every aisle is reachable — the case set the AC-39.4 render order walks.
    @Test func allAislesAreCaseIterable() {
        #expect(Aisle.allCases.count == 6)
        #expect(Set(Aisle.allCases.map(\.rawValue)).count == 6)
    }
}
