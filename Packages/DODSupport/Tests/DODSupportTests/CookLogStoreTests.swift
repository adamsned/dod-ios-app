import Foundation
import Testing

@testable import DODSupport

@Suite("CookLogStore") struct CookLogStoreTests {

    private static func freshDefaults() throws -> UserDefaults {
        let name = "dod.widget.cookLog.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func recordThenReadRoundTrips() throws {
        let store = WidgetSnapshotStore(defaults: try Self.freshDefaults())
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        store.recordCook(at: when)
        #expect(store.readCookDates() == [when])
    }

    @Test func oldEventsArePruned() throws {
        let store = WidgetSnapshotStore(defaults: try Self.freshDefaults())
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = now.addingTimeInterval(-400 * 86_400)
        store.recordCook(at: old)
        store.recordCook(at: now)
        #expect(store.readCookDates() == [now])
    }

    @Test func emptyStoreGivesEmptyStats() throws {
        let store = WidgetSnapshotStore(defaults: try Self.freshDefaults())
        #expect(store.readCookStreakStats() == .empty)
    }
}
