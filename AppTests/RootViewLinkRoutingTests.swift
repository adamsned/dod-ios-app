import XCTest

@testable import DODApp

/// DUT-462 / DUT-243 — an in-app recipe link routes into the stack of the tab
/// it was tapped from (captured at tap time, before the async resolve), except
/// the Cooking Tools hub, which has no article surface and redirects to Feed.
/// The tab capture-before-await itself is a view-layer ordering guarantee; this
/// pins the pure destination rule that the router drives off.
final class RootViewLinkRoutingTests: XCTestCase {

    func testLinkStaysInTheTabItWasTappedFrom() {
        XCTAssertEqual(RootView.linkRoutingDestination(for: .feed), .feed)
        XCTAssertEqual(RootView.linkRoutingDestination(for: .saved), .saved)
        // v2 Search overhaul (1/3) — Search is no longer a tab, so there's no
        // `.search` origin to assert here; a link tapped on the pushed search
        // page rides the Feed stack (the tab it lives in).
    }

    func testCookingToolsLinkRedirectsToFeed() {
        // T-912 / DUT-551 (CL-306) — the Cooking Tools hub renders no article
        // surface / recipe stack, so a link tapped there routes to Feed rather
        // than dead-ending (as the retired Grocery/Settings tabs did).
        XCTAssertEqual(RootView.linkRoutingDestination(for: .cookingTools), .feed)
    }
}
