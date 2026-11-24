import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

@MainActor
@Suite("Cook Journal confidence stats (DUT-975)")
struct CookJournalConfidenceStatsTests {

    static func entry(_ confidence: Int, day: Int) -> CookLogEntry {
        CookLogEntry(
            id: UUID(),
            recipeID: 1,
            recipeTitle: "Pasta",
            cookedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(day) * 86_400),
            confidence: confidence
        )
    }

    @Test func threeEntriesGiveReadsAndNoTrend() {
        let cooks = [
            Self.entry(1, day: 0),
            Self.entry(3, day: 1),
            Self.entry(5, day: 2),
        ]
        let stats = CookJournalView.computeStats(cooks)
        #expect(stats.confidenceReads == [1, 3, 5])
        #expect(stats.confidenceTrend == nil)
    }

    @Test func risingSeriesGivesPositiveTrend() {
        let cooks = [1, 2, 4, 5].enumerated().map { Self.entry($1, day: $0) }
        let stats = CookJournalView.computeStats(cooks)
        #expect(stats.confidenceReads == [1, 2, 4, 5])
        let trend = stats.confidenceTrend ?? 0
        #expect(trend > 0)
    }
}
