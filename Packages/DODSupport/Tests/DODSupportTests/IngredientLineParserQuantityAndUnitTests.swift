import Foundation
import Testing

@testable import DODSupport

/// Comprehensive coverage of ``IngredientLineParser.parseQuantityAndUnit(_:)``,
/// which parses a bare quantity+unit line (with no ingredient name required).
/// This function differs from ``parse(_:)`` in that it returns the recovered
/// `(quantity, unit)` tuple even when no name follows, enabling unit conversion
/// of lines like `"2 cups"` → `"480 ml"` (DUT-913).
@Suite("IngredientLineParser.parseQuantityAndUnit")
struct IngredientLineParserQuantityAndUnitTests {

    // MARK: - Happy path and basics

    @Test func happyPathParsesTwoUnits() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 cups")
        #expect(result != nil)
        #expect(result?.quantity == 2)
        #expect(result?.unit == "cup")
    }

    @Test func parsesIntegerQuantity() {
        let result = IngredientLineParser.parseQuantityAndUnit("3 tablespoons")
        #expect(result?.quantity == 3)
        #expect(result?.unit == "tablespoon")
    }

    // MARK: - Nil cases (no quantity or no recognized unit)

    @Test func returnsNilWhenNoLeadingQuantity() {
        let result = IngredientLineParser.parseQuantityAndUnit("cups of flour")
        #expect(result == nil)
    }

    @Test func returnsNilWhenQuantityButNoRecognizedUnit() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 large eggs")
        #expect(result == nil)
    }

    // MARK: - Quantity forms

    @Test func parsesSlashFraction() {
        let result = IngredientLineParser.parseQuantityAndUnit("1/2 cup")
        #expect(result?.quantity == 0.5)
        #expect(result?.unit == "cup")
    }

    @Test func parsesDecimalQuantity() {
        let result = IngredientLineParser.parseQuantityAndUnit("1.5 cups")
        #expect(result?.quantity == 1.5)
        #expect(result?.unit == "cup")
    }

    @Test func parsesUnicodeVulgarFraction() {
        let result = IngredientLineParser.parseQuantityAndUnit("½ cup")
        #expect(result?.quantity == 0.5)
        #expect(result?.unit == "cup")
    }

    @Test func parsesThreeFourthsFraction() {
        let result = IngredientLineParser.parseQuantityAndUnit("¾ cup")
        #expect(result?.quantity == 0.75)
        #expect(result?.unit == "cup")
    }

    @Test func parsesMixedNumberWithVulgarFraction() {
        let result = IngredientLineParser.parseQuantityAndUnit("1 ½ cups")
        #expect(result?.quantity == 1.5)
        #expect(result?.unit == "cup")
    }

    @Test func parsesMixedNumberWithSlashFraction() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 1/3 cups")
        #expect(result?.quantity == 2 + 1.0 / 3.0)
        #expect(result?.unit == "cup")
    }

    // MARK: - Parenthetical annotation stripping (DUT-667)

    @Test func stripsLeadingParentheticalAnnotationBetweenQuantityAndUnit() {
        let result = IngredientLineParser.parseQuantityAndUnit("1 (14 oz) can")
        #expect(result?.quantity == 1)
        #expect(result?.unit == "can")
    }

    @Test func stripsParentheticalWithMultipleWords() {
        let result = IngredientLineParser.parseQuantityAndUnit("1 (14 ounces) can")
        #expect(result?.quantity == 1)
        #expect(result?.unit == "can")
    }

    @Test func returnsNilWhenUnterminatedParenthetical() {
        let result = IngredientLineParser.parseQuantityAndUnit("1 (14 oz cup")
        #expect(result == nil)
    }

    @Test func returnsNilWhenParenthesisHasNoMatch() {
        let result = IngredientLineParser.parseQuantityAndUnit("1 (oz cup")
        #expect(result == nil)
    }

    // MARK: - Whitespace handling

    @Test func trimsLeadingAndTrailingWhitespace() {
        let result = IngredientLineParser.parseQuantityAndUnit("  2 cups  ")
        #expect(result?.quantity == 2)
        #expect(result?.unit == "cup")
    }

    @Test func trimsWhitespaceAroundQuantityAndUnit() {
        let result = IngredientLineParser.parseQuantityAndUnit("  1.5   tablespoons  ")
        #expect(result?.quantity == 1.5)
        #expect(result?.unit == "tablespoon")
    }

    // MARK: - Unit normalization (plural to singular)

    @Test func normalizesPlural() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 cups")
        #expect(result?.unit == "cup")
    }

    @Test func normalizesTablespoonPlural() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 tablespoons")
        #expect(result?.unit == "tablespoon")
    }

    @Test func normalizesOunces() {
        let result = IngredientLineParser.parseQuantityAndUnit("8 ounces")
        #expect(result?.unit == "ounce")
    }

    @Test func normalizesPounds() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 pounds")
        #expect(result?.unit == "pound")
    }

    @Test func normalizesGrams() {
        let result = IngredientLineParser.parseQuantityAndUnit("250 grams")
        #expect(result?.unit == "gram")
    }

    @Test func normalizesMilliliters() {
        let result = IngredientLineParser.parseQuantityAndUnit("500 milliliters")
        #expect(result?.unit == "milliliter")
    }

    @Test func normalizesCans() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 cans")
        #expect(result?.unit == "can")
    }

    // MARK: - Unit abbreviations

    @Test func recognizesCupAbbreviation() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 c")
        #expect(result?.unit == "cup")
    }

    @Test func recognizesTablespoonAbbreviation() {
        let result = IngredientLineParser.parseQuantityAndUnit("3 tbsp")
        #expect(result?.unit == "tablespoon")
    }

    @Test func recognizesTeaspoonAbbreviation() {
        let result = IngredientLineParser.parseQuantityAndUnit("1 tsp")
        #expect(result?.unit == "teaspoon")
    }

    @Test func recognizesOunceAbbreviation() {
        let result = IngredientLineParser.parseQuantityAndUnit("8 oz")
        #expect(result?.unit == "ounce")
    }

    @Test func recognizesPoundAbbreviation() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 lb")
        #expect(result?.unit == "pound")
    }

    @Test func recognizesGramAbbreviation() {
        let result = IngredientLineParser.parseQuantityAndUnit("250 g")
        #expect(result?.unit == "gram")
    }

    @Test func recognizesMilliliterAbbreviation() {
        let result = IngredientLineParser.parseQuantityAndUnit("500 ml")
        #expect(result?.unit == "milliliter")
    }

    @Test func recognizesQuart() {
        let result = IngredientLineParser.parseQuantityAndUnit("1 quart")
        #expect(result?.unit == "quart")
    }

    @Test func recognizesPint() {
        let result = IngredientLineParser.parseQuantityAndUnit("1 pint")
        #expect(result?.unit == "pint")
    }

    // MARK: - Edge cases

    @Test func returnsNilForEmptyString() {
        let result = IngredientLineParser.parseQuantityAndUnit("")
        #expect(result == nil)
    }

    @Test func returnsNilForWhitespaceOnly() {
        let result = IngredientLineParser.parseQuantityAndUnit("   \t  ")
        #expect(result == nil)
    }

    @Test func returnsNilWhenOnlyUnitWithoutQuantity() {
        let result = IngredientLineParser.parseQuantityAndUnit("cup")
        #expect(result == nil)
    }

    @Test func returnsNilWhenOnlyNumberWithoutUnit() {
        let result = IngredientLineParser.parseQuantityAndUnit("2")
        #expect(result == nil)
    }

    @Test func returnsNilForUnrecognizedUnit() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 foobar")
        #expect(result == nil)
    }

    @Test func trimsTrailingPeriodFromUnit() {
        // readUnit() trims trailing "." and ",", so "cup." matches "cup"
        let result = IngredientLineParser.parseQuantityAndUnit("2 cup.")
        #expect(result?.unit == "cup")
    }

    @Test func trimsTrailingCommaFromUnit() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 cup,")
        #expect(result?.unit == "cup")
    }

    // MARK: - Case insensitivity

    @Test func normalizesCaseInsensitively() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 CUP")
        #expect(result?.unit == "cup")
    }

    @Test func normalizesMixedCaseUnit() {
        let result = IngredientLineParser.parseQuantityAndUnit("3 TbSp")
        #expect(result?.unit == "tablespoon")
    }

    // MARK: - Complex combinations

    @Test func handlesComplexParentheticalWithDecimal() {
        let result = IngredientLineParser.parseQuantityAndUnit("1.5 (14 oz) can")
        #expect(result?.quantity == 1.5)
        #expect(result?.unit == "can")
    }

    @Test func handlesParentheticalWithMixedNumber() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 1/2 (14 oz) can")
        #expect(result?.quantity == 2.5)
        #expect(result?.unit == "can")
    }

    @Test func convertsOuncesToOunceUnit() {
        let result = IngredientLineParser.parseQuantityAndUnit("16 ounces")
        #expect(result?.quantity == 16)
        #expect(result?.unit == "ounce")
    }

    @Test func handlesKilograms() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 kilograms")
        #expect(result?.quantity == 2)
        #expect(result?.unit == "kilogram")
    }

    @Test func handlesLiter() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 liters")
        #expect(result?.quantity == 2)
        #expect(result?.unit == "liter")
    }

    @Test func handlesCloves() {
        let result = IngredientLineParser.parseQuantityAndUnit("3 cloves")
        #expect(result?.quantity == 3)
        #expect(result?.unit == "clove")
    }

    @Test func handlesPackage() {
        let result = IngredientLineParser.parseQuantityAndUnit("1 package")
        #expect(result?.quantity == 1)
        #expect(result?.unit == "package")
    }

    @Test func handlesSprig() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 sprigs")
        #expect(result?.quantity == 2)
        #expect(result?.unit == "sprig")
    }

    @Test func handlesStick() {
        let result = IngredientLineParser.parseQuantityAndUnit("1 stick")
        #expect(result?.quantity == 1)
        #expect(result?.unit == "stick")
    }

    @Test func handlesSlice() {
        let result = IngredientLineParser.parseQuantityAndUnit("2 slices")
        #expect(result?.quantity == 2)
        #expect(result?.unit == "slice")
    }

    @Test func handlesPinch() {
        let result = IngredientLineParser.parseQuantityAndUnit("1 pinch")
        #expect(result?.quantity == 1)
        #expect(result?.unit == "pinch")
    }
}
