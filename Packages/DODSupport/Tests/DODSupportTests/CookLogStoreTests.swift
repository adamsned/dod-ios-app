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

    @Test func statsReflectRecordedCooks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        func day(_ dayOfMonth: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 11, day: dayOfMonth, hour: 12)) ?? Date()
        }
        let store = WidgetSnapshotStore(defaults: try Self.freshDefaults())
        store.recordCook(at: day(3), calendar: calendar)
        store.recordCook(at: day(4), calendar: calendar)
        let stats = store.readCookStreakStats(now: day(4), calendar: calendar)
        #expect(stats.hasAnyCooks)
        #expect(stats.streakDays == 2)
        #expect(stats.cooksThisWeek == 2)
    }
}
