import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

/// Tests for the BringListReminder helper functions.
@Suite("BringListReminder") struct BringListReminderTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func futureDateReturnsSecondsUntil() {
        let result = SystemBringListReminder.interval(
            until: now.addingTimeInterval(3600),
            now: now
        )
        #expect(result == 3600)
    }

    @Test func pastDateReturnsNil() {
        let result = SystemBringListReminder.interval(
            until: now.addingTimeInterval(-60),
            now: now
        )
        #expect(result == nil)
    }

    @Test func dateEqualToNowReturnsNil() {
        #expect(SystemBringListReminder.interval(until: now, now: now) == nil)
    }

    @Test func identifierIsStable() {
        #expect(SystemBringListReminder.identifier == "dod.bringList.packTheTruck")
    }
}
