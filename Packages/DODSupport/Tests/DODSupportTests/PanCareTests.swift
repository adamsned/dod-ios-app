import Foundation
import Testing

@testable import DODSupport

@Suite("PanCare (DUT-971)")
struct PanCareTests {
    @Test func stepOrder() {
        #expect(PanCareStep.allCases.map(\.rawValue) == ["wipe", "oil", "done"])
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now) ?? now
    }

    private func cook(daysAgo days: Int) -> CookLogEntry {
        CookLogEntry(id: UUID(), recipeID: 1, recipeTitle: "Bread", cookedAt: daysAgo(days))
    }

    @Test func noEntriesIsNotIdle() {
        #expect(!PanCare.isIdle(cooks: [], cares: [], now: now, calendar: calendar))
    }

    @Test func recentCookIsNotIdle() {
        #expect(!PanCare.isIdle(cooks: [cook(daysAgo: 5)], cares: [], now: now, calendar: calendar))
    }

    @Test func oldCookIsIdle() {
        #expect(PanCare.isIdle(cooks: [cook(daysAgo: 30)], cares: [], now: now, calendar: calendar))
    }

    @Test func recentCareResetsIdle() {
        let care = PanCareEntry(careAt: daysAgo(2))
        #expect(!PanCare.isIdle(cooks: [cook(daysAgo: 30)], cares: [care], now: now, calendar: calendar))
    }
}
