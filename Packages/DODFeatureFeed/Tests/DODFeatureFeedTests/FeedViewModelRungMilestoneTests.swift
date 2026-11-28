import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// DUT-964 — a logged cook queues a ladder milestone, below graduation and
/// first-cook-ever in priority.
@MainActor
@Suite("FeedViewModel rung milestones (DUT-964)") struct FeedViewModelRungMilestoneTests {

    @Test func secondDistinctRungQueuesRungMilestone() async {
        let dependencies = FakeFeedDependencies()
        dependencies.cooks = [makeCook(GuidedCookout.firstCookout.recipeID)]
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.logCook(makeCook(GuidedCookout.italianChicken.recipeID))

        let expected = RungMilestone.rungCleared(
            cleared: GuidedCookout.italianChicken,
            next: GuidedCookout.campfire
        )
        #expect(viewModel.celebration == .rungMilestone(expected))
    }

    @Test func firstCookEverStillWinsOverRung() async {
        let dependencies = FakeFeedDependencies()
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.logCook(makeCook(GuidedCookout.firstCookout.recipeID))

        #expect(viewModel.celebration == .firstCookEver)
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
