import DODFeatureFeed
import XCTest

@testable import DODApp

final class WhatsNewPresenterTests: XCTestCase {
    func testPresentsExactlyOnceAfterUpdate() throws {
        let name = "WhatsNewPresenterTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }

        WhatsNewGate.baselineIfNeeded(currentVersion: "2.0", defaults: defaults)
        XCTAssertTrue(
            WhatsNewGate.shouldPresent(
                currentVersion: "2.1",
                lastSeenVersion: WhatsNewGate.lastSeen(defaults: defaults)
            )
        )
        WhatsNewGate.markSeen("2.1", defaults: defaults)
        XCTAssertFalse(
            WhatsNewGate.shouldPresent(
                currentVersion: "2.1",
                lastSeenVersion: WhatsNewGate.lastSeen(defaults: defaults)
            )
        )
    }
}
