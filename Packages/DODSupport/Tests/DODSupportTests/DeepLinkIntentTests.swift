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

    @Test func cookModeURLWithoutIDReturnsNil() throws {
        let url = try #require(URL(string: "dod://recipe/cook"))
        #expect(DeepLinkIntent.parse(url) == nil)
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
}
