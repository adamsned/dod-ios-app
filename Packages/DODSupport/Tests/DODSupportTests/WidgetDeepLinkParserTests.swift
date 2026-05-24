import Foundation
import Testing

@testable import DODSupport

/// Behavioural tests for the home-screen widget's deep-link scheme.
///
/// Spec trace: spec.md US-9 AC-9.2.
@Suite("WidgetDeepLinkParser") struct WidgetDeepLinkParserTests {

    @Test func parsesRecipeWithPositiveID() throws {
        let url = try #require(URL(string: "dod://recipe/4641"))
        #expect(WidgetDeepLinkParser.parse(url) == .recipe(id: 4641))
    }

    @Test func parsesFeedRoute() throws {
        let url = try #require(URL(string: "dod://feed"))
        #expect(WidgetDeepLinkParser.parse(url) == .feed)
    }

    @Test func schemeIsCaseInsensitive() throws {
        let url = try #require(URL(string: "DOD://recipe/12"))
        #expect(WidgetDeepLinkParser.parse(url) == .recipe(id: 12))
    }

    @Test func wrongSchemeIsRejected() throws {
        let url = try #require(URL(string: "https://www.dutchovendaddy.com/recipe/1"))
        #expect(WidgetDeepLinkParser.parse(url) == nil)
    }

    @Test func zeroOrNegativeRecipeIDIsRejected() throws {
        let zero = try #require(URL(string: "dod://recipe/0"))
        #expect(WidgetDeepLinkParser.parse(zero) == nil)
        let negative = try #require(URL(string: "dod://recipe/-3"))
        #expect(WidgetDeepLinkParser.parse(negative) == nil)
    }

    @Test func nonNumericRecipeIDIsRejected() throws {
        let url = try #require(URL(string: "dod://recipe/abc"))
        #expect(WidgetDeepLinkParser.parse(url) == nil)
    }

    @Test func emptyPathIsRejected() throws {
        // `dod://recipe` with no id is meaningless.
        let url = try #require(URL(string: "dod://recipe"))
        #expect(WidgetDeepLinkParser.parse(url) == nil)
    }

    @Test func unknownHostIsRejected() throws {
        let url = try #require(URL(string: "dod://settings/notifications"))
        #expect(WidgetDeepLinkParser.parse(url) == nil)
    }
}
