import Foundation
import Testing

@testable import DODSupport

/// Coverage for ``IngredientLineParser`` quantity parsing, focused on the
/// DUT-393 glued vulgar-fraction regression (`"1½"` used to parse as quantity 0
/// because `Character.isNumber` is `true` for `½`, so the digit scan swallowed
/// the glyph and `Double("1½")` returned `nil → 0`).
@Suite("IngredientLineParser quantities")
struct IngredientLineParserTests {

    @Test func gluedVulgarFractionParsesWithNoSpace() {
        let parsed = IngredientLineParser.parse("1½ cups flour")
        #expect(parsed.quantity == 1.5)
        #expect(parsed.unit == "cup")
        #expect(parsed.name == "flour")
    }

    @Test func gluedQuarterFractionParses() {
        let parsed = IngredientLineParser.parse("2¼ cup sugar")
        #expect(parsed.quantity == 2.25)
        #expect(parsed.unit == "cup")
        #expect(parsed.name == "sugar")
    }

    /// The spaced mixed form must still work after the ASCII digit-scan change.
    @Test func spacedMixedFractionStillParses() {
        let parsed = IngredientLineParser.parse("1 ½ cups flour")
        #expect(parsed.quantity == 1.5)
        #expect(parsed.unit == "cup")
        #expect(parsed.name == "flour")
    }

    /// A leading standalone vulgar fraction is unchanged.
    @Test func leadingBareVulgarFractionParses() {
        let parsed = IngredientLineParser.parse("½ cup milk")
        #expect(parsed.quantity == 0.5)
        #expect(parsed.unit == "cup")
        #expect(parsed.name == "milk")
    }

    @Test func plainIntegerAndDecimalStillParse() {
        #expect(IngredientLineParser.parse("2 cups flour").quantity == 2)
        #expect(IngredientLineParser.parse("1.5 cups flour").quantity == 1.5)
        #expect(IngredientLineParser.parse("1/2 cup water").quantity == 0.5)
    }

    // MARK: - DUT-667 leading parenthetical size annotation

    /// A leading `(… )` size annotation between the quantity and the unit is
    /// stripped before the unit/name scan, so the unit reads `can` (not a bogus
    /// `(14` word) and the name is `black beans`.
    @Test func leadingParentheticalSizeStripped() {
        let parsed = IngredientLineParser.parse("1 (14 oz) can black beans")
        #expect(parsed.quantity == 1)
        #expect(parsed.unit == "can")
        #expect(parsed.name == "black beans")
    }

    /// A parenthetical later in the line (not immediately after the quantity)
    /// stays in the name — only a LEADING annotation is dropped.
    @Test func nonLeadingParentheticalKeptInName() {
        let parsed = IngredientLineParser.parse("2 cups broth (low sodium)")
        #expect(parsed.quantity == 2)
        #expect(parsed.unit == "cup")
        #expect(parsed.name == "broth (low sodium)")
    }
}
