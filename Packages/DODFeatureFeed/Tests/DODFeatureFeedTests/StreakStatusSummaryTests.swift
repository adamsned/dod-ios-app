import DODSupport
import Testing

@testable import DODFeatureFeed

@Suite("Streak status summary (DUT-972)")
struct StreakStatusSummaryTests {
    @Test func safeSummary() {
        let summary = StreakStatusSummary(status: .safe(streak: 3))
        #expect(summary.headline == "3-week streak")
    }

    @Test func atRiskSummaryUsesSmallestRep() {
        let summary = StreakStatusSummary(status: .atRisk(streak: 2))
        #expect(summary.detail.contains("skillet"))
    }

    @Test func noneSummaryInvitesStart() {
        let summary = StreakStatusSummary(status: .none)
        #expect(summary.headline == "Start a streak")
    }
}
