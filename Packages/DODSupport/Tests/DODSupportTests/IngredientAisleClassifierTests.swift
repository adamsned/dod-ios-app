import Foundation
import Testing

@testable import DODSupport

/// Golden L1 coverage for ``IngredientAisleClassifier``.
///
/// Spec trace: US-39 / AC-39.4 (aisle grouping), AC-39.12 (pure on-device).
/// CL-67 (static keyword-map strategy), CL-80 (logic-core split). Constitution
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

    // MARK: - Equal-length keyword ties (DUT-497)

    // A line matching two equal-length keywords from different aisles must
    // resolve DETERMINISTICALLY (same result every launch/build), not by the
    // randomized `Dictionary.keys` iteration order. The tiebreak is a total
    // order: length descending, then the keyword itself ascending — so among
    // equal-length keywords the alphabetically-first keyword wins. Each case
    // is asserted at the concrete aisle that tiebreak selects, and re-run in a
    // loop to prove the result is stable within a process.

    @Test func beefBeatsRiceOnEqualLengthTie() {
        // "beef" (.meat) vs "rice" (.pantry), both length 4 → "beef" < "rice".
        for _ in 0..<64 {
            #expect(IngredientAisleClassifier.classify("beef and rice bowl") == .meat)
        }
    }

    @Test func steakBeatsThymeOnEqualLengthTie() {
        // "steak" (.meat) vs "thyme" (.spices), both length 5 → "steak" < "thyme".
        for _ in 0..<64 {
            #expect(IngredientAisleClassifier.classify("steak rubbed with thyme") == .meat)
        }
    }

    @Test func eggBeatsHamOnEqualLengthTie() {
        // "egg" (.dairy) vs "ham" (.meat), both length 3 → "egg" < "ham".
        for _ in 0..<64 {
            #expect(IngredientAisleClassifier.classify("ham and egg") == .dairy)
        }
    }

    // MARK: - DUT-661 pantry compounds win over their fragment

    /// Canned/boxed pantry compounds must bucket to `.pantry`, not the bare
    /// produce/meat/dairy fragment they contain — the longest-first scan tests
    /// the compound before its fragment.
    @Test func pantryCompoundsBeatTheirFragment() {
        #expect(IngredientAisleClassifier.classify("2 cups chicken broth") == .pantry)
        #expect(IngredientAisleClassifier.classify("1 cup chicken stock") == .pantry)
        #expect(IngredientAisleClassifier.classify("1 tsp chicken bouillon") == .pantry)
        #expect(IngredientAisleClassifier.classify("1 can coconut milk") == .pantry)
        #expect(IngredientAisleClassifier.classify("1 cup almond milk") == .pantry)
        #expect(IngredientAisleClassifier.classify("½ cup oat milk") == .pantry)
        #expect(IngredientAisleClassifier.classify("1 can tomato sauce") == .pantry)
        #expect(IngredientAisleClassifier.classify("1 can cream of mushroom soup") == .pantry)
    }

    /// The bare fragments still classify to their own aisle unchanged.
    @Test func bareFragmentsUnchanged() {
        #expect(IngredientAisleClassifier.classify("2 lbs chicken thighs") == .meat)
        #expect(IngredientAisleClassifier.classify("1 cup whole milk") == .dairy)
        #expect(IngredientAisleClassifier.classify("2 diced tomato") == .produce)
    }

    // MARK: - Short-keyword END boundary (a short stem must not match as a
    // mere PREFIX of a longer, unrelated word)

    /// "ham" (.meat) must not match inside "hamburger" — "buns" isn't a
    /// mapped keyword either, so the correct result is the `.other` fallback.
    @Test func hamburgerBunsAreNotMeat() {
        #expect(IngredientAisleClassifier.classify("4 hamburger buns") == .other)
    }

    /// "rice" (.pantry) must not match inside "riced" — "cauliflower" isn't
    /// mapped, so the correct result is `.other`, not a false pantry hit.
    @Test func ricedCauliflowerIsNotPantry() {
        #expect(IngredientAisleClassifier.classify("1 cup riced cauliflower") == .other)
    }

    /// "salt" (.spices) must not match inside "saltine" — a cracker line
    /// should fall to `.other`, not be misfiled as a spice.
    @Test func saltineCrackersAreNotSpices() {
        #expect(IngredientAisleClassifier.classify("1 sleeve saltine crackers") == .other)
    }

    /// Regression guard: the new END check must not break plain plurals —
    /// "eggs" still finds the "egg" stem.
    @Test func pluralEggsStillMatchAfterTheFix() {
        #expect(IngredientAisleClassifier.classify("2 large eggs") == .dairy)
    }

    /// Regression guard: another plural, "hams", still finds the "ham" stem.
    @Test func pluralHamsStillMatchAfterTheFix() {
        #expect(IngredientAisleClassifier.classify("2 lbs cured hams") == .meat)
    }

    /// Regression guard for the already-fixed (DUT-716) mid-word cases —
    /// unrelated to this fix, must keep passing: "ham" doesn't match inside
    /// "graham", and "salt" doesn't match inside "unsalted".
    @Test func midWordFragmentsStillExcluded() {
        #expect(IngredientAisleClassifier.classify("a slice of graham cracker") != .meat)
        #expect(IngredientAisleClassifier.classify("2 cups unsalted butter") == .dairy)
    }

    // MARK: - Enum completeness

    /// Every aisle is reachable — the case set the AC-39.4 render order walks.
    @Test func allAislesAreCaseIterable() {
        #expect(Aisle.allCases.count == 6)
        #expect(Set(Aisle.allCases.map(\.rawValue)).count == 6)
    }
}
