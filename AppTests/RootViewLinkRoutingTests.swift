import XCTest

@testable import DODApp

/// DUT-462 / DUT-243 — an in-app recipe link routes into the stack of the tab
/// it was tapped from (captured at tap time, before the async resolve), except
/// Settings, which has no article surface and redirects to Feed. The tab
/// capture-before-await itself is a view-layer ordering guarantee; this pins the
/// pure destination rule that the router drives off.
final class RootViewLinkRoutingTests: XCTestCase {

    func testLinkStaysInTheTabItWasTappedFrom() {
        XCTAssertEqual(RootView.linkRoutingDestination(for: .feed), .feed)
        XCTAssertEqual(RootView.linkRoutingDestination(for: .saved), .saved)
        XCTAssertEqual(RootView.linkRoutingDestination(for: .search), .search)
    }

    func testSettingsLinkRedirectsToFeed() {
        // Settings renders no article surface, so a link tapped there routes to
        // Feed rather than dead-ending.
        XCTAssertEqual(RootView.linkRoutingDestination(for: .settings), .feed)
    }

    func testGroceryLinkRedirectsToFeed() {
        // DUT-536 — the Grocery List tab renders only the Shopping List (no
        // article surface / recipe stack), so a link routes to Feed like
        // Settings rather than dead-ending.
        XCTAssertEqual(RootView.linkRoutingDestination(for: .grocery), .feed)
    }
}
