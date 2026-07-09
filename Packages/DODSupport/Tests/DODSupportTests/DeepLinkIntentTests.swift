import Foundation
import Testing

@testable import DODSupport

@Suite("DeepLinkIntent (US-10 / AC-10.2)") struct DeepLinkIntentTests {

    @Test func openRecipeURLParsesID() throws {
        let url = try #require(URL(string: "dod://recipe?id=4641"))
        #expect(DeepLinkIntent.parse(url) == .openRecipe(id: 4641))
    }

    @Test func cookModeURLParsesID() throws {
        let url = try #require(URL(string: "dod://recipe/cook?id=723"))
        #expect(DeepLinkIntent.parse(url) == .startCookMode(recipeID: 723))
    }

    @Test func savedURLParsesAsOpenSaved() throws {
        let url = try #require(URL(string: "dod://saved"))
        #expect(DeepLinkIntent.parse(url) == .openSaved)
    }

    @Test func recipeURLWithoutIDReturnsNil() throws {
        let url = try #require(URL(string: "dod://recipe"))
        #expect(DeepLinkIntent.parse(url) == nil)
    }

    // MARK: - DUT-603

    /// `dod://recipe/123` — the id rides the trailing path component, mirroring
    /// the article grammar, so it parses without a `?id=` query.
    @Test func recipePathURLParsesID() throws {
        let url = try #require(URL(string: "dod://recipe/4641"))
        #expect(DeepLinkIntent.parse(url) == .openRecipe(id: 4641))
    }

    /// Zero, negative, and non-numeric recipe-path ids fall through to nil.
    @Test func recipePathURLWithBadIDReturnsNil() throws {
        let zero = try #require(URL(string: "dod://recipe/0"))
        #expect(DeepLinkIntent.parse(zero) == nil)
        let negative = try #require(URL(string: "dod://recipe/-5"))
        #expect(DeepLinkIntent.parse(negative) == nil)
        let nonNumeric = try #require(URL(string: "dod://recipe/abc"))
        #expect(DeepLinkIntent.parse(nonNumeric) == nil)
    }

    /// A path-bearing `saved` variant is malformed and must not route
    /// (matching WidgetDeepLinkParser's bare-host gate).
    @Test func savedWithPathReturnsNil() throws {
        let withPath = try #require(URL(string: "dod://saved/123"))
        #expect(DeepLinkIntent.parse(withPath) == nil)
        // Bare + trailing-slash forms both still route to saved.
        let trailingSlash = try #require(URL(string: "dod://saved/"))
        #expect(DeepLinkIntent.parse(trailingSlash) == .openSaved)
    }

    @Test func cookModeURLWithoutIDReturnsNil() throws {
        let url = try #require(URL(string: "dod://recipe/cook"))
        #expect(DeepLinkIntent.parse(url) == nil)
    }

    /// DUT — cook-mode ids must be positive, mirroring the recipe/article
    /// branches. `?id=0` / `?id=-5` fetch post 0 downstream and dead-end in a
    /// "Couldn't open that recipe" toast, so they must parse to nil.
    @Test func cookModeURLWithNonPositiveIDReturnsNil() throws {
        let zero = try #require(URL(string: "dod://recipe/cook?id=0"))
        #expect(DeepLinkIntent.parse(zero) == nil)
        let negative = try #require(URL(string: "dod://recipe/cook?id=-5"))
        #expect(DeepLinkIntent.parse(negative) == nil)
    }

    @Test func unknownSchemeReturnsNil() throws {
        let url = try #require(URL(string: "https://example.com/recipe?id=1"))
        #expect(DeepLinkIntent.parse(url) == nil)
    }

    @Test func unknownActionReturnsNil() throws {
        let url = try #require(URL(string: "dod://nonsense"))
        #expect(DeepLinkIntent.parse(url) == nil)
    }

    /// Round-trip: every intent must serialize to a URL the parser accepts.
    /// Locks the URL contract so AppIntents and onOpenURL never disagree.
    @Test func roundTripOpenRecipe() {
        let intent = DeepLinkIntent.openRecipe(id: 99)
        #expect(DeepLinkIntent.parse(intent.url) == intent)
    }

    @Test func roundTripCookMode() {
        let intent = DeepLinkIntent.startCookMode(recipeID: 42)
        #expect(DeepLinkIntent.parse(intent.url) == intent)
    }

    @Test func roundTripOpenSaved() {
        let intent = DeepLinkIntent.openSaved
        #expect(DeepLinkIntent.parse(intent.url) == intent)
    }

    /// Non-numeric id should fall through to nil rather than crash.
    @Test func recipeURLWithGarbageIDReturnsNil() throws {
        let url = try #require(URL(string: "dod://recipe?id=abc"))
        #expect(DeepLinkIntent.parse(url) == nil)
    }

    // MARK: - DUT-566 `dod://article/<id>` (notification grammar)

    /// `dod://article/<id>` (the notification grammar for `.article` posts)
    /// resolves by post id to the same `.openRecipe(id:)` route as a recipe —
    /// `PostKind` lives on `Recipe`, so the detail view classifies the kind
    /// once the post is resolved.
    @Test func articlePathURLParsesID() throws {
        let url = try #require(URL(string: "dod://article/123"))
        #expect(DeepLinkIntent.parse(url) == .openRecipe(id: 123))
    }

    /// The `?id=` query form is accepted too, mirroring the recipe host.
    @Test func articleQueryURLParsesID() throws {
        let url = try #require(URL(string: "dod://article?id=99"))
        #expect(DeepLinkIntent.parse(url) == .openRecipe(id: 99))
    }

    /// Zero, negative, non-numeric, or missing ids fall through to nil.
    @Test func articleURLWithBadIDReturnsNil() throws {
        let zero = try #require(URL(string: "dod://article/0"))
        #expect(DeepLinkIntent.parse(zero) == nil)
        let negative = try #require(URL(string: "dod://article/-3"))
        #expect(DeepLinkIntent.parse(negative) == nil)
        let nonNumeric = try #require(URL(string: "dod://article/abc"))
        #expect(DeepLinkIntent.parse(nonNumeric) == nil)
        let empty = try #require(URL(string: "dod://article"))
        #expect(DeepLinkIntent.parse(empty) == nil)
    }
}
