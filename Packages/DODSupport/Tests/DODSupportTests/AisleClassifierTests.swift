import DODDomain
import Foundation
import Testing

@testable import DODSupport

/// L1 coverage for ``AisleClassifier`` — pins the static keyword-map
/// classifier strategy per CL-67 and the bell-pepper carve-out the
/// header comment documents.
///
/// Spec trace: US-39 / AC-39.4 (the classified value drives aisle
/// grouping), AC-39.10 (raw value is the telemetry payload), CL-67
/// (strategy + design intent).
@Suite("AisleClassifier") struct AisleClassifierTests {

    // MARK: - Per-aisle representative wins (≥3 per aisle)

    @Test func produce_onion() {
        #expect(AisleClassifier.classify("1 medium yellow onion, diced") == .produce)
    }

    @Test func produce_garlic() {
        #expect(AisleClassifier.classify("3 cloves garlic, minced") == .produce)
    }

    @Test func produce_carrots() {
        #expect(AisleClassifier.classify("2 large carrots, chopped") == .produce)
    }

    @Test func produce_freshHerb() {
        #expect(AisleClassifier.classify("2 tbsp fresh parsley, chopped") == .produce)
    }

    @Test func pantry_oliveOil() {
        #expect(AisleClassifier.classify("2 tablespoons olive oil") == .pantry)
    }

    @Test func pantry_flour() {
        #expect(AisleClassifier.classify("3 cups all-purpose flour") == .pantry)
    }

    @Test func pantry_tomatoPaste() {
        #expect(AisleClassifier.classify("1 6-oz can tomato paste") == .pantry)
    }

    @Test func pantry_brownSugar() {
        #expect(AisleClassifier.classify("1/2 cup brown sugar, packed") == .pantry)
    }

    @Test func dairy_wholeMilk() {
        #expect(AisleClassifier.classify("1 1/2 cups whole milk") == .dairy)
    }

    @Test func dairy_butter() {
        #expect(AisleClassifier.classify("4 tablespoons unsalted butter") == .dairy)
    }

    @Test func dairy_cheese() {
        #expect(AisleClassifier.classify("1 cup shredded cheddar cheese") == .dairy)
    }

    @Test func meat_groundBeef() {
        #expect(AisleClassifier.classify("1 lb ground beef, 80/20") == .meat)
    }

    @Test func meat_chickenBreast() {
        #expect(
            AisleClassifier.classify("2 boneless skinless chicken breast halves")
                == .meat
        )
    }

    @Test func meat_bacon() {
        #expect(AisleClassifier.classify("4 slices thick-cut bacon") == .meat)
    }

    @Test func spices_blackPepper() {
        #expect(AisleClassifier.classify("1 tsp freshly cracked black pepper") == .spices)
    }

    @Test func spices_paprika() {
        #expect(AisleClassifier.classify("1 tablespoon smoked paprika") == .spices)
    }

    @Test func spices_cumin() {
        #expect(AisleClassifier.classify("1/2 tsp ground cumin") == .spices)
    }

    @Test func bakery_bread() {
        #expect(AisleClassifier.classify("1 loaf crusty sourdough bread") == .bakery)
    }

    @Test func bakery_tortillas() {
        #expect(AisleClassifier.classify("8 flour tortillas") == .bakery)
    }

    @Test func bakery_buns() {
        #expect(AisleClassifier.classify("4 brioche buns") == .bakery)
    }

    @Test func frozen_iceCream() {
        #expect(AisleClassifier.classify("1 pint vanilla ice cream") == .frozen)
    }

    @Test func frozen_frozenPeas() {
        #expect(AisleClassifier.classify("1 cup frozen peas") == .frozen)
    }

    @Test func frozen_frozenCorn() {
        #expect(AisleClassifier.classify("2 cups frozen corn kernels") == .frozen)
    }

    // MARK: - Bell-pepper carve-out (load-bearing)

    /// The header comment promises that "bell pepper" routes to
    /// **produce** before the bare `"pepper"` single-token lookup
    /// fires (which would route to spices). This is the load-bearing
    /// test for the carve-out — if a future change reorders the
    /// phrase scan or drops the entry, this is the canary.
    @Test func bellPepperCarveOut_routesToProduce() {
        #expect(AisleClassifier.classify("1 red bell pepper, diced") == .produce)
    }

    // MARK: - Case insensitivity

    @Test func caseInsensitive_uppercaseTomatoMatchesProduce() {
        #expect(AisleClassifier.classify("TOMATO") == .produce)
    }

    @Test func caseInsensitive_mixedCaseFlourMatchesPantry() {
        #expect(AisleClassifier.classify("1 Cup All-Purpose FLOUR") == .pantry)
    }

    // MARK: - Quantity / unit prefixes ignored

    /// Mixed-fraction quantity + unit prefix doesn't block the dairy
    /// match — the tokenizer walks past "1", "1/2", "cups", "whole"
    /// and lands on "milk".
    @Test func quantityPrefixIgnored_milkRoutesToDairy() {
        #expect(AisleClassifier.classify("1 1/2 cups whole milk") == .dairy)
    }

    @Test func unicodeFractionIgnored_butterRoutesToDairy() {
        #expect(AisleClassifier.classify("½ cup unsalted butter") == .dairy)
    }

    // MARK: - Punctuation stripping

    @Test func punctuationStripped_garlicMincedRoutesToProduce() {
        #expect(AisleClassifier.classify("garlic, minced") == .produce)
    }

    @Test func parensStripped_chickenInParensRoutesToMeat() {
        #expect(AisleClassifier.classify("2 lb chicken (bone-in)") == .meat)
    }

    // MARK: - Multi-word phrase beats single-token

    /// Tomato sauce → pantry, even though bare "tomato" → produce.
    /// Pins the phrase-scan-first ordering.
    @Test func multiWordBeatsSingleToken_tomatoSauce() {
        #expect(AisleClassifier.classify("1 15-oz can tomato sauce") == .pantry)
    }

    /// Ground beef → meat, even though bare "ground" isn't in the
    /// single-token map (it would otherwise fall through to .other).
    @Test func multiWordBeatsSingleToken_groundChickenRoutesToMeat() {
        #expect(AisleClassifier.classify("1 lb ground chicken") == .meat)
    }

    // MARK: - Fallback to .other

    @Test func unknownTokenFallsBackToOther() {
        #expect(AisleClassifier.classify("xyzunknown") == .other)
    }

    @Test func emptyStringFallsBackToOther() {
        #expect(AisleClassifier.classify("") == .other)
    }

    @Test func whitespaceOnlyFallsBackToOther() {
        #expect(AisleClassifier.classify("   \t  \n  ") == .other)
    }
}
