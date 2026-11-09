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
}
