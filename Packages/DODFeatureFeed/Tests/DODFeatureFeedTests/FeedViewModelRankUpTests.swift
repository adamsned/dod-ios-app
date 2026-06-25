import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// DUT-323 — logging a cook that bumps the cook up a rank surfaces the milestone
/// celebration; one that stays within the rank doesn't.
@MainActor
@Suite("FeedViewModel rank-up celebration (DUT-323)") struct FeedViewModelRankUpTests {

    @Test func loggingACookThatCrossesAThresholdFiresTheCelebration() async {
        let dependencies = FakeFeedDependencies()
        dependencies.cooks = [makeCook(1), makeCook(2)]  // 2 cooks -> Fire Starter
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.logCook(makeCook(3))  // 3rd cook crosses to Coal Tender

        #expect(viewModel.rankUpCelebration?.title == "Coal Tender")
    }

    @Test func loggingACookThatStaysInRankDoesNotCelebrate() async {
        let dependencies = FakeFeedDependencies()
        dependencies.cooks = [makeCook(1)]  // 1 cook -> Fire Starter
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.logCook(makeCook(2))  // 2nd cook -> still Fire Starter (next is 3)

        #expect(viewModel.rankUpCelebration == nil)
    }

    @Test func dismissingClearsTheCelebration() async {
        let dependencies = FakeFeedDependencies()
        dependencies.cooks = [makeCook(1), makeCook(2)]
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.logCook(makeCook(3))
        #expect(viewModel.rankUpCelebration != nil)

        viewModel.dismissRankUpCelebration()

        #expect(viewModel.rankUpCelebration == nil)
    }

    private func makeCook(_ id: Int) -> CookLogEntry {
        CookLogEntry(
            id: UUID(),
            recipeID: id,
            recipeTitle: "R\(id)",
            cookedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
