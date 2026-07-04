import Foundation
import Testing

@testable import DODNetworking

/// L1 coverage for the still-need-line → Instacart line-item mapping (DUT-532).
/// Pins the parse-and-map contract: quantity-only, quantity+unit, unparseable
/// fallback to raw text, verbatim `display_text`, and empty-line skipping.
struct InstacartLineItemMapperTests {

    @Test func mapsQuantityAndName() throws {
        let items = InstacartLineItemMapper.lineItems(from: ["2 limes"])
        let item = try #require(items.first)
        #expect(item.name == "limes")
        #expect(item.quantity == 2)
        #expect(item.unit == nil)
        #expect(item.displayText == "2 limes")
    }

    @Test func mapsQuantityUnitAndName() throws {
        let items = InstacartLineItemMapper.lineItems(from: ["1 lb chicken thighs"])
        let item = try #require(items.first)
        #expect(item.name == "chicken thighs")
        #expect(item.quantity == 1)
        // `lb` normalizes to the canonical singular `pound` (IngredientLineParser).
        #expect(item.unit == "pound")
        #expect(item.displayText == "1 lb chicken thighs")
    }

    @Test func fallsBackToRawTextForUnparseableLine() throws {
        let items = InstacartLineItemMapper.lineItems(from: ["black pepper to taste"])
        let item = try #require(items.first)
        // No leading quantity → parser yields nil name; the mapper falls back to
        // the raw line so nothing is dropped.
        #expect(item.name == "black pepper to taste")
        #expect(item.quantity == nil)
        #expect(item.unit == nil)
        #expect(item.displayText == "black pepper to taste")
    }

    @Test func skipsEmptyAndWhitespaceLines() {
        let items = InstacartLineItemMapper.lineItems(from: ["", "   ", "\n", "2 limes"])
        #expect(items.count == 1)
        #expect(items.first?.name == "limes")
    }

    @Test func mapsMultipleLinesInOrder() {
        let items = InstacartLineItemMapper.lineItems(from: [
            "3 lb beef chuck roast",
            "1 yellow onion, quartered",
            "salt to taste",
        ])
        #expect(items.count == 3)
        #expect(items.map(\.displayText) == [
            "3 lb beef chuck roast",
            "1 yellow onion, quartered",
            "salt to taste",
        ])
    }

    @Test func defaultTitleIsBranded() {
        #expect(InstacartLineItemMapper.defaultTitle == "Dutch Oven Daddy Shopping List")
    }
}
