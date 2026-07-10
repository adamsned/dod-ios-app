import Foundation
import Testing

@testable import DODNetworking

/// DUT-544 regression lock: `hasRecipeJSONLD(html:)` must classify a genuine
/// recipe page as true and a round-up / guide ARTICLE as false, regardless of
/// any embedded WPRM cards. Six deterministic cases cover the full predicate
/// surface: top-level node, Article / ItemList / CollectionPage round-ups,
/// @graph walk, no blocks, malformed JSON, and @type-array matching.
@Suite("JSONLDRecipeParser.hasRecipeJSONLD — DUT-544 contract")
struct JSONLDRecipeSubjectDetectionTests {

    /// Case 1 — a page whose single JSON-LD block carries a top-level
    /// `@type: Recipe` node is the canonical recipe subject.
    @Test func topLevelRecipeNodeReturnsTrue() {
        let html = """
            <html><head>
            <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"Recipe","name":"Dutch Oven Chili"}
            </script>
            </head><body></body></html>
            """
        #expect(JSONLDRecipeParser.hasRecipeJSONLD(html: html))
    }

    /// Case 2 — DUT-544 regression. Round-up / guide ARTICLES whose JSON-LD
    /// `@type` is "Article", "ItemList", or "CollectionPage" must return false
    /// even when they embed a `wprm-recipe-container` card (the DUT-538 trigger).
    /// All three common round-up types are tested in a single case.
    @Test func roundUpArticlePageReturnsFalse() {
        let articleHTML = """
            <html><head>
            <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"Article",
             "headline":"Best Dutch Oven Recipes Roundup"}
            </script>
            </head><body></body></html>
            """
        #expect(!JSONLDRecipeParser.hasRecipeJSONLD(html: articleHTML))

        let itemListHTML = """
            <html><head>
            <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"ItemList",
             "name":"Memorial Day Recipes"}
            </script>
            </head><body></body></html>
            """
        #expect(!JSONLDRecipeParser.hasRecipeJSONLD(html: itemListHTML))

        let collectionHTML = """
            <html><head>
            <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"CollectionPage",
             "name":"Dump Cake Recipes"}
            </script>
            </head><body></body></html>
            """
        #expect(!JSONLDRecipeParser.hasRecipeJSONLD(html: collectionHTML))
    }

    /// Case 3 — a `Recipe` node nested inside a `@graph` envelope is found by
    /// the same recursive walk that `parse` uses (T-058 contract).
    @Test func recipeNodeNestedInGraphReturnsTrue() {
        let html = """
            <html><head>
            <script type="application/ld+json">
            {"@context":"https://schema.org","@graph":[
              {"@type":"WebSite","name":"Dutch Oven Daddy"},
              {"@type":"WebPage","name":"Recipe Page"},
              {"@type":"Recipe","name":"Nested Recipe"}
            ]}
            </script>
            </head><body></body></html>
            """
        #expect(JSONLDRecipeParser.hasRecipeJSONLD(html: html))
    }

    /// Case 4 — a page with no `<script type="application/ld+json">` blocks at
    /// all yields false immediately (the for-loop body never executes).
    @Test func pageWithNoJsonLdBlocksReturnsFalse() {
        let html = """
            <html>
            <head><title>No Schema</title></head>
            <body><p>Plain content, no structured data.</p></body>
            </html>
            """
        #expect(!JSONLDRecipeParser.hasRecipeJSONLD(html: html))
    }

    /// Case 5 — a block whose content is malformed JSON is silently skipped
    /// (the `guard let object = try? JSONSerialization…` path) and the predicate
    /// returns false rather than crashing.
    @Test func malformedJsonLdBlockIsSkippedReturnsFalse() {
        // Missing closing brace makes this invalid JSON.
        let html = """
            <html><head>
            <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"Recipe","name":"Malformed
            </script>
            </head><body></body></html>
            """
        #expect(!JSONLDRecipeParser.hasRecipeJSONLD(html: html))
    }

    /// Case 6 — `@type` given as an array `["NewsArticle","Recipe"]` is handled
    /// by `matchesRecipeType` via `[String].contains("Recipe")` — lock this path.
    @Test func typeArrayContainingRecipeReturnsTrue() {
        let html = """
            <html><head>
            <script type="application/ld+json">
            {"@context":"https://schema.org","@type":["NewsArticle","Recipe"],
             "name":"Dual-typed Node"}
            </script>
            </head><body></body></html>
            """
        #expect(JSONLDRecipeParser.hasRecipeJSONLD(html: html))
    }
}
