import DODSupport
import XCTest

@testable import DODApp

/// DUT-566 — a tapped notification carrying `dod://article/<id>` must route
/// through the *shared* `DeepLinkIntent.parse` (the same parser
/// `RootView.onOpenURL` uses), not the private hand-parser, and still dispatch
/// `.openRecipe(id:)`. `didReceive` needs a `UNNotificationResponse` that can't
/// be constructed in a unit test, so the routing decision is factored into the
/// pure `NotificationCoordinator.intent(fromDeepLink:)` seam these tests drive.
final class NotificationCoordinatorRoutingTests: XCTestCase {

    // MARK: - The DUT-566 fix: `dod://article/<id>` round-trips through the parser

    func testArticleDeepLinkRoutesToOpenRecipeByID() {
        XCTAssertEqual(
            NotificationCoordinator.intent(fromDeepLink: "dod://article/123"),
            .openRecipe(id: 123)
        )
    }

    /// The grammar round-trips through the shared parser: the same URL fed to
    /// `RootView.onOpenURL` resolves to the identical intent.
    func testArticleDeepLinkMatchesSharedParser() {
        guard let url = URL(string: "dod://article/123") else {
            return XCTFail("static URL literal failed to parse")
        }
        XCTAssertEqual(
            NotificationCoordinator.intent(fromDeepLink: "dod://article/123"),
            DeepLinkIntent.parse(url)
        )
    }

    // MARK: - Existing behavior preserved

    func testRecipeDeepLinkStillRoutesToOpenRecipeByID() {
        // The notification's recipe grammar is path-based (`dod://recipe/<id>`),
        // which the shared parser's `?id=`-only recipe case doesn't accept — so
        // this exercises the `postID` fallback, proving no regression.
        XCTAssertEqual(
            NotificationCoordinator.intent(fromDeepLink: "dod://recipe/456"),
            .openRecipe(id: 456)
        )
    }

    func testMalformedDeepLinkReturnsNil() {
        XCTAssertNil(NotificationCoordinator.intent(fromDeepLink: "dod://article/abc"))
        XCTAssertNil(NotificationCoordinator.intent(fromDeepLink: "https://example.com/1"))
        XCTAssertNil(NotificationCoordinator.intent(fromDeepLink: "not a url"))
    }
}
