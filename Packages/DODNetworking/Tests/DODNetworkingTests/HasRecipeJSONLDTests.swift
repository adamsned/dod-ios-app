import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODNetworking

/// DUT-544: the recipe-SUBJECT signal. `hasRecipeJSONLD` must cleanly separate a
/// genuine recipe (a `@type: Recipe` node in the JSON-LD) from a round-up /
/// guide ARTICLE that merely embeds a WPRM card (Article / ItemList JSON-LD, no
/// Recipe node). Validated 2026-07-04 against the live `dutch-oven-7-can-soup`
/// recipe vs. the `dump-cake-recipes` / `memorial-day-recipes` round-ups.
@Suite("JSONLDRecipeParser.hasRecipeJSONLD (DUT-544)") struct HasRecipeJSONLDTests {

    /// The 7 Can Soup shape: its JSON-LD carries a `Recipe` node (even though
    /// that node OMITS `recipeIngredient`/`recipeInstructions`). Recipe subject
    /// → true. Preserves DUT-538 for this exact page.
    @Test func trueForRecipeFixtureEvenWithEmptyRecipeFields() throws {
        let html = try loadFixture("seven-can-soup")
        #expect(JSONLDRecipeParser.hasRecipeJSONLD(html: html))
    }

    /// The round-up shape: Article + ItemList JSON-LD, a `wprm-recipe-container`
    /// embedded card, and a real article body — but NO `Recipe` node. Article
    /// subject → false, so the classifier routes it to the article body instead
    /// of dumping the embedded card in place of the whole post.
    @Test func falseForRoundUpArticleThatEmbedsACard() throws {
        let html = try loadFixture("round-up-with-embedded-card")
        // Sanity: it really does embed a WPRM card (the DUT-538 trigger)...
        #expect(WPRMRecipeCardParser.hasRecipeCard(html: html))
        // ...yet it is NOT recipe-typed, so the subject signal says article.
        #expect(!JSONLDRecipeParser.hasRecipeJSONLD(html: html))
    }

    /// A Recipe node nested inside a `@graph` envelope is detected identically
    /// to the top-level shape (same walk `parse` uses).
    @Test func trueForRecipeNodeInsideGraph() {
        let html = """
            <html><head><script type="application/ld+json">
            {"@context":"https://schema.org","@graph":[
              {"@type":"WebPage","name":"x"},
              {"@type":"Recipe","name":"Real Recipe"}
            ]}
            </script></head><body></body></html>
            """
        #expect(JSONLDRecipeParser.hasRecipeJSONLD(html: html))
    }

    /// No JSON-LD, or JSON-LD without a Recipe node → false.
    @Test func falseWhenNoRecipeNodePresent() {
        #expect(!JSONLDRecipeParser.hasRecipeJSONLD(html: "<html><body><p>no schema</p></body></html>"))
        let articleOnly = """
            <html><head><script type="application/ld+json">
            {"@context":"https://schema.org","@type":"Article","headline":"Guide"}
            </script></head><body></body></html>
            """
        #expect(!JSONLDRecipeParser.hasRecipeJSONLD(html: articleOnly))
    }

    private func loadFixture(_ name: String) throws -> String {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "html"),
            "Fixture \(name).html not found in test bundle"
        )
        return try String(contentsOf: url, encoding: .utf8)
    }
}
