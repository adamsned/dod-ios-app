import XCTest

@testable import DODFeatureFeed

final class PanCareNotifierTests: XCTestCase {

    func testDelayReturnsCorrectValue() {
        // Test that delay returns 21*86400 - 86400 for lastActivity 1 day before now
        let now = Date()
        let lastActivity = now.addingTimeInterval(-86_400)  // 1 day ago

        let delay = SystemPanCareNotifier.delay(lastActivity: lastActivity, now: now)

        // Should be 21 days minus 1 day = 20 days in seconds
        XCTAssertEqual(delay, 20 * 86_400)
    }

    func testDelayIsNilWhenLastActivityIs30DaysBeforeNow() {
        // Test that delay is nil when lastActivity is 30 days before now
        let now = Date()
        let lastActivity = now.addingTimeInterval(-30 * 86_400)  // 30 days ago

        let delay = SystemPanCareNotifier.delay(lastActivity: lastActivity, now: now)

        XCTAssertNil(delay)
    }

    func testConstantsAreCorrect() {
        // Test that identifier, title, and body are non-empty and identifier equals "dod.panCare.idleReminder"
        XCTAssertEqual(SystemPanCareNotifier.identifier, "dod.panCare.idleReminder")
        XCTAssertFalse(SystemPanCareNotifier.title.isEmpty)
        XCTAssertFalse(SystemPanCareNotifier.body.isEmpty)
    }
}
