import Foundation
import Testing

@testable import DODSupport

@Suite("PanCareStore (DUT-971)")
struct PanCareStoreTests {
    @Test func logCareTwiceReturnsNewestFirst() throws {
        let suite = "PanCareStoreTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PanCareStore(defaults: defaults)
        let older = store.logCare(at: Date(timeIntervalSince1970: 1_000))
        let newer = store.logCare(at: Date(timeIntervalSince1970: 2_000))
        let result = store.entries()
        #expect(result.count == 2)
        #expect(result.map(\.id) == [newer.id, older.id])
    }

    @Test func loggingBeyondCapKeepsNewest200() throws {
        let suite = "PanCareStoreTests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PanCareStore(defaults: defaults)
        for index in 0..<205 {
            store.logCare(at: Date(timeIntervalSince1970: Double(index)))
        }
        let result = store.entries()
        #expect(result.count == 200)
        #expect(result.first?.careAt == Date(timeIntervalSince1970: 204))
        #expect(result.last?.careAt == Date(timeIntervalSince1970: 5))
    }
}
