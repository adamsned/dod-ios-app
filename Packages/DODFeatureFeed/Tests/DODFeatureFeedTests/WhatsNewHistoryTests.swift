import DODDomain
import DODNetworking
import XCTest

@testable import DODFeatureFeed

final class WhatsNewHistoryTests: XCTestCase {

    func testLatestReturnsNilForEmptyArray() {
        XCTAssertNil(WhatsNewHistoryView.latest([]))
    }

    func testLatestReturnsFirstElementOtherwise() {
        let release = ChangelogRelease(
            version: "2.0",
            title: "Version 2.0",
            bullets: ["Improvement"]
        )
        XCTAssertEqual(WhatsNewHistoryView.latest([release]), release)
    }
}
