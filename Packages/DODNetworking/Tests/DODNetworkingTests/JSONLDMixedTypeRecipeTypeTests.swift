import Foundation
import Testing

@testable import DODNetworking

/// DUT-916 — `@type` in JSON-LD may be a string OR an array, and some WPRM/plugin
/// configs emit a MIXED array (a stray null/number alongside the strings). The
/// old whole-array `raw as? [String]` failed on one non-string element, so a
/// genuine recipe went undetected and rendered as a plain article. Per-element
/// matching (mirroring the #606 mapIngredients / DUT-214 mapVideo fixes) keeps
/// the recipe detected. All-string arrays are unaffected.
@Suite("JSON-LD matchesRecipeType mixed @type array (DUT-916)")
struct JSONLDMixedTypeRecipeTypeTests {

    @Test func plainStringRecipeStillMatches() {
        #expect(JSONLDRecipeParser.matchesRecipeType("Recipe") == true)
    }

    @Test func allStringArrayStillMatches() {
        let arr: [Any] = ["Recipe", "NewsArticle"]
        #expect(JSONLDRecipeParser.matchesRecipeType(arr) == true)
    }

    @Test func mixedArrayWithTrailingNumberStillMatches() {
        // The DUT-916 regression: a stray number no longer drops the match.
        let arr: [Any] = ["Recipe", 123]
        #expect(JSONLDRecipeParser.matchesRecipeType(arr) == true)
    }

    @Test func mixedArrayWithNullStillMatches() {
        let arr: [Any] = ["Recipe", NSNull()]
        #expect(JSONLDRecipeParser.matchesRecipeType(arr) == true)
    }

    @Test func mixedArrayWithoutRecipeDoesNotMatch() {
        let arr: [Any] = ["Article", 123, NSNull()]
        #expect(JSONLDRecipeParser.matchesRecipeType(arr) == false)
    }

    @Test func nonArrayNonStringDoesNotMatch() {
        #expect(JSONLDRecipeParser.matchesRecipeType(42) == false)
        #expect(JSONLDRecipeParser.matchesRecipeType(nil) == false)
    }
}
