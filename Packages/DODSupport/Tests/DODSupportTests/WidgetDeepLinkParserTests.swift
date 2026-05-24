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

    // MARK: - US-17 `dod://saved` cases (AC-17.4, AC-17.5, AC-17.8)

    @Test func parsesSavedRoute() throws {
        let url = try #require(URL(string: "dod://saved"))
        #expect(WidgetDeepLinkParser.parse(url) == .saved)
    }

    /// Trailing slash is the same logical URL — accept it, mirroring how
    /// `URL.path` normalizes `dod://saved/` to an empty path component.
    @Test func parsesSavedRouteWithTrailingSlash() throws {
        let url = try #require(URL(string: "dod://saved/"))
        #expect(WidgetDeepLinkParser.parse(url) == .saved)
    }

    /// Anything after the host is malformed — the widget only ever emits
    /// the bare `dod://saved`. Reject so a hostile pasteboard URL can't
    /// piggy-back on the Saved tab route.
    @Test func savedRouteWithExtraPathIsRejected() throws {
        let url = try #require(URL(string: "dod://saved/foo"))
        #expect(WidgetDeepLinkParser.parse(url) == nil)
    }

    /// And the numeric variant — guard against `dod://saved/<id>` being
    /// misread as a recipe deep link.
    @Test func savedRouteWithNumericPathIsRejected() throws {
        let url = try #require(URL(string: "dod://saved/123"))
        #expect(WidgetDeepLinkParser.parse(url) == nil)
    }

    /// Case-insensitive scheme + host — same contract as
    /// `schemeIsCaseInsensitive` above so the parser doesn't care about
    /// how iOS canonicalizes the URL between processes.
    @Test func savedRouteIsCaseInsensitive() throws {
        let url = try #require(URL(string: "Dod://Saved"))
        #expect(WidgetDeepLinkParser.parse(url) == .saved)
    }

    // MARK: - T-323 / AC-17.9 `source` query parameter

    /// The saved widget's recipe-row tap emits `?source=saved` so the
    /// host app can fire `widgetOpened(kind: .saved, recipeID:)` instead
    /// of mis-attributing the open to the featured widget.
    @Test func parsesRecipeWithSavedSource() throws {
        let url = try #require(URL(string: "dod://recipe/4641?source=saved"))
        #expect(WidgetDeepLinkParser.parse(url) == .recipe(id: 4641, source: .saved))
    }

    /// Featured widget URLs continue to omit the query parameter; the
    /// parser must keep treating them as `.featured` so existing analytics
    /// for the today's-featured surface aren't broken by T-323.
    @Test func parsesRecipeWithoutSourceDefaultsToFeatured() throws {
        let url = try #require(URL(string: "dod://recipe/12"))
        #expect(WidgetDeepLinkParser.parse(url) == .recipe(id: 12, source: .featured))
    }

    /// Unknown `source` values fall back to `.featured` rather than
    /// rejecting the URL — the navigation contract still holds, the
    /// analytics layer just attributes to the default surface.
    @Test func parsesRecipeWithUnknownSourceFallsBackToFeatured() throws {
        let url = try #require(URL(string: "dod://recipe/12?source=banana"))
        #expect(WidgetDeepLinkParser.parse(url) == .recipe(id: 12, source: .featured))
    }

    /// Source query parameter is case-insensitive — same forgiveness as
    /// the scheme + host parsing above.
    @Test func parsesRecipeSourceCaseInsensitive() throws {
        let url = try #require(URL(string: "dod://recipe/9?source=SAVED"))
        #expect(WidgetDeepLinkParser.parse(url) == .recipe(id: 9, source: .saved))
    }
}
