import Foundation
import Testing

@testable import DODFeatureFeed

@Suite("RecipeOfTheDayStore (DUT-117)")
struct RecipeOfTheDayStoreTests {

    @Test("dayKeyIsZeroPaddedLocalDate")
    func dayKeyIsZeroPaddedLocalDate() {
        let calendar = Calendar(identifier: .gregorian)
        guard let timeZone = TimeZone(identifier: "UTC") else {
            Issue.record("Failed to create time zone")
            return
        }
        var calendarWithUTC = calendar
        calendarWithUTC.timeZone = timeZone
        let date = Date(timeIntervalSince1970: 1_700_000_000)  // 2023-11-14

        let result = RecipeOfTheDayStore.dayKey(for: date, calendar: calendarWithUTC)
        #expect(result == "2023-11-14")
    }

    @Test("pickedIDOnlyMatchesTheRecordedDay")
    func pickedIDOnlyMatchesTheRecordedDay() {
        guard let defaults = UserDefaults(suiteName: UUID().uuidString) else {
            Issue.record("Failed to create user defaults")
            return
        }
        let store = RecipeOfTheDayStore(defaults: defaults)

        store.record(id: 5, dayKey: "2026-10-23")

        #expect(store.pickedID(forDayKey: "2026-10-23") == 5)
        #expect(store.pickedID(forDayKey: "2026-10-24") == nil)
    }

    @Test("historyIsMostRecentFirstDedupedAndCapped")
    func historyIsMostRecentFirstDedupedAndCapped() {
        guard let defaults = UserDefaults(suiteName: UUID().uuidString) else {
            Issue.record("Failed to create user defaults")
            return
        }
        let store = RecipeOfTheDayStore(defaults: defaults)

        // Record ids 1...40 on distinct day keys, then record 40 again
        for index in 1...40 {
            store.record(id: index, dayKey: "2026-10-\(String(format: "%02d", index))")
        }
        store.record(id: 40, dayKey: "2026-10-30")  // Record 40 again

        let recentIDs = store.recentIDs()
        #expect(recentIDs.count == RecipeOfTheDayStore.historyLimit)
        #expect(recentIDs.first == 40)
        #expect(recentIDs.filter { $0 == 40 }.count == 1)
    }

    @Test("emptyStoreHasNoPickOrHistory")
    func emptyStoreHasNoPickOrHistory() {
        guard let defaults = UserDefaults(suiteName: UUID().uuidString) else {
            Issue.record("Failed to create user defaults")
            return
        }
        let store = RecipeOfTheDayStore(defaults: defaults)

        #expect(store.pickedID(forDayKey: "2026-10-23") == nil)
        #expect(store.recentIDs().isEmpty)
    }
}
