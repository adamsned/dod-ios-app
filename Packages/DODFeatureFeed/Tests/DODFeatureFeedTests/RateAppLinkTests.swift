import Foundation
import Testing

@testable import DODFeatureFeed

@Suite struct RateAppLinkTests {
    @Test func urlIsWriteReviewDeepLink() throws {
        let url = try #require(URL(string: SettingsView.rateAppURLString))
        #expect(url.host == "apps.apple.com")
        #expect(url.query == "action=write-review")
    }
}
