import DODDomain
import Foundation
import XCTest

@testable import DODApp

final class RootViewLinkPlacementTests: XCTestCase {

    private func sampleRoute() -> RecipeRoute {
        let item = RecipeListItem(
            id: 7,
            title: "Corn",
            excerpt: "",
            publishedAt: .distantPast,
            canonicalURL: URL(string: "https://dutchovendaddy.com/corn/") ?? URL(filePath: "/")
        )
        return .recipe(item: item, autoStartCookMode: false)
    }

    func testExternalLinkReplacesFeedStackFromAnyTab() {
        for origin in AppTab.allCases {
            let placement = RootView.linkPlacement(for: sampleRoute(), external: true, originTab: origin)
            XCTAssertEqual(placement.tab, .feed)
            XCTAssertEqual(placement.route, .replaceStack(sampleRoute()))
        }
    }

    func testInAppLinkPushesOntoOriginTab() {
        let placement = RootView.linkPlacement(for: sampleRoute(), external: false, originTab: .saved)
        XCTAssertEqual(placement.tab, .saved)
        XCTAssertEqual(placement.route, .push(sampleRoute()))
    }

    func testInAppLinkFromCookingToolsRedirectsToFeed() {
        let placement = RootView.linkPlacement(for: sampleRoute(), external: false, originTab: .cookingTools)
        XCTAssertEqual(placement.tab, .feed)
    }

    func testExternalLinkFromSavedIsReplaceStackNotPush() {
        let placement = RootView.linkPlacement(for: sampleRoute(), external: true, originTab: .saved)
        XCTAssertEqual(placement.route, .replaceStack(sampleRoute()))
        XCTAssertNotEqual(placement.route, .push(sampleRoute()))
    }
}
