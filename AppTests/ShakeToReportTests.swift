import XCTest

@testable import DODApp

final class ShakeToReportTests: XCTestCase {

    func test_appTab_shakeScreenIDs() {
        XCTAssertEqual(AppTab.feed.shakeScreenID, "feed")
        XCTAssertEqual(AppTab.saved.shakeScreenID, "saved")
        XCTAssertEqual(AppTab.cookingTools.shakeScreenID, "cooking_tools")
    }

    func test_deviceDidShake_notificationDoesNotCrash() {
        // Post the shake notification and ensure nothing crashes
        NotificationCenter.default.post(name: .deviceDidShake, object: nil)

        // Just verifying that posting the notification doesn't crash
        XCTAssert(true)
    }
}
