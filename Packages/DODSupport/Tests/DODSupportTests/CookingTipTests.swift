import Foundation
import Testing

@testable import DODSupport

/// L1 coverage for the DUT-454 inline cooking-tip rotation. The widget builds a
/// 14-day timeline from `CookingTip.tip(for:)`, so the pick must be stable
/// within a day and rotate across days.
@Suite("CookingTip (DUT-454)")
struct CookingTipTests {

    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return cal
    }

    private let day0 = Date(timeIntervalSince1970: 1_781_000_000)  // a fixed instant

    @Test func tipIsStableWithinADay() {
        let sameDayLater = day0.addingTimeInterval(6 * 60 * 60)
        #expect(CookingTip.tip(for: day0, calendar: utc) == CookingTip.tip(for: sameDayLater, calendar: utc))
    }

    @Test func tipRotatesAcrossConsecutiveDays() throws {
        let cal = utc
        var tips: [String] = []
        for offset in 0..<CookingTip.all.count {
            let day = try #require(cal.date(byAdding: .day, value: offset, to: day0))
            tips.append(CookingTip.tip(for: day, calendar: cal))
        }
        // One full cycle should cover every distinct tip exactly once.
        #expect(Set(tips) == Set(CookingTip.all))
    }

    @Test func tipWrapsAfterAFullCycle() throws {
        let cal = utc
        let afterCycle = try #require(cal.date(byAdding: .day, value: CookingTip.all.count, to: day0))
        #expect(CookingTip.tip(for: day0, calendar: cal) == CookingTip.tip(for: afterCycle, calendar: cal))
    }
}
