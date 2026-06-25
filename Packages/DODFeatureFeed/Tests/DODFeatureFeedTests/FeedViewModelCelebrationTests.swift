import DODDomain
import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// DUT-323 — a logged cook can earn a celebration: a rank-up when it crosses a
/// ladder threshold, or (the bigger beat) graduating the whole First Cookout
/// path. Graduation supersedes a rank-up; an in-rank cook celebrates nothing.
@MainActor
@Suite("FeedViewModel cook celebration (DUT-323)") struct FeedViewModelCelebrationTests {

    // IDs well clear of the path rungs (1459 / 683 / 22294) so these never
    // accidentally graduate — they isolate the rank-up path.
    @Test func loggingACookThatCrossesAThresholdFiresARankUp() async {
        let dependencies = FakeFeedDependencies()
        dependencies.cooks = [makeCook(9001), makeCook(9002)]  // 2 cooks -> Fire Starter
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.logCook(makeCook(9003))  // 3rd cook crosses to Coal Tender

        if case .rankUp(let rank) = viewModel.celebration {
            #expect(rank.title == "Coal Tender")
        } else {
            Issue.record("expected a rank-up, got \(String(describing: viewModel.celebration))")
        }
    }

    @Test func loggingACookThatStaysInRankCelebratesNothing() async {
        let dependencies = FakeFeedDependencies()
        dependencies.cooks = [makeCook(9001)]  // 1 cook -> Fire Starter
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.logCook(makeCook(9002))  // 2nd cook -> still Fire Starter (next is 3)

        #expect(viewModel.celebration == nil)
    }

    @Test func graduatingTheFirstCookoutPathFiresGraduationOverRankUp() async {
        let dependencies = FakeFeedDependencies()
        let rungs = GuidedCookout.path
        // Every rung but the last is already cooked.
        dependencies.cooks = rungs.dropLast().map { makeCook($0.recipeID) }
        let viewModel = FeedViewModel(dependencies: dependencies)
        guard let lastRung = rungs.last else {
            Issue.record("path has no rungs")
            return
        }

        // The final-rung cook completes the path. It also crosses a rank
        // threshold (2 -> 3 cooks), so this asserts graduation wins.
        await viewModel.logCook(makeCook(lastRung.recipeID))

        #expect(viewModel.celebration == .graduatedFirstCookout)
    }

    @Test func dismissingClearsTheCelebration() async {
        let dependencies = FakeFeedDependencies()
        dependencies.cooks = [makeCook(9001), makeCook(9002)]
        let viewModel = FeedViewModel(dependencies: dependencies)
        await viewModel.logCook(makeCook(9003))
        #expect(viewModel.celebration != nil)

        viewModel.dismissCelebration()

        #expect(viewModel.celebration == nil)
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
