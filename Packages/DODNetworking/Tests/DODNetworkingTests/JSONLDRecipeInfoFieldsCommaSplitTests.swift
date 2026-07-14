import Foundation
import Testing

@testable import DODNetworking

/// DUT-572 follow-up: schema.org types `recipeCategory` / `recipeCuisine` as
/// `Text` (singular), not an array — so WPRM (and similar plugins) join
/// MULTIPLE assigned categories/cuisines into ONE comma-separated string
/// (e.g. `"recipeCategory": "Dinner, Main Course"`) rather than emitting an
/// array. `mapStringOrArray`'s bare-string branch previously wrapped that
/// whole joined string as a SINGLE tag; it now splits on commas.
@Suite("JSONLDRecipeParser.mapStringOrArray comma-joined Text field")
struct MapStringOrArrayCommaSplitTests {

    @Test("splits a comma-joined multi-category string into separate tags")
    func splitsCommaJoinedCategories() {
        #expect(JSONLDRecipeParser.mapStringOrArray("Dinner, Main Course") == ["Dinner", "Main Course"])
    }

    @Test("a single value with no comma is returned unchanged")
    func singleValueWithNoCommaIsUnchanged() {
        #expect(JSONLDRecipeParser.mapStringOrArray("Dessert") == ["Dessert"])
    }

    @Test("trims stray whitespace around the comma separator")
    func trimsWhitespaceAroundComma() {
        #expect(JSONLDRecipeParser.mapStringOrArray("Breakfast ,  Brunch") == ["Breakfast", "Brunch"])
    }
}
