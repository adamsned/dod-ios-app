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

    /// DUT-208 — when the journal write fails, the photo the flow wrote to disk
    /// before handing off must be deleted so it isn't orphaned (no journal row
    /// will ever reference its `photoLocalID`).
    @Test func failedLogCookDeletesTheOrphanedPhoto() async {
        let dependencies = FakeFeedDependencies()
        dependencies.logCookShouldFail = true
        let viewModel = FeedViewModel(dependencies: dependencies)

        let entry = CookLogEntry(
            id: UUID(),
            recipeID: 9100,
            recipeTitle: "R9100",
            cookedAt: Date(timeIntervalSince1970: 1_700_000_000),
            photoLocalID: "orphan-photo-9100.jpg"
        )
        await viewModel.logCook(entry)

        #expect(dependencies.deletedCookPhotoIDs == ["orphan-photo-9100.jpg"])
    }

    /// DUT-208 — a failed write with no photo attached must not attempt a delete.
    @Test func failedLogCookWithNoPhotoDeletesNothing() async {
        let dependencies = FakeFeedDependencies()
        dependencies.logCookShouldFail = true
        let viewModel = FeedViewModel(dependencies: dependencies)

        await viewModel.logCook(makeCook(9101))  // makeCook attaches no photo

        #expect(dependencies.deletedCookPhotoIDs.isEmpty)
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

    /// DUT-625 — a first-ever cook that is an off-path DUMP CAKE must NOT fire a
    /// rank-up. The rank ladder counts the path population only (graduation is
    /// path-only), so an "Anytime Treat" can't spuriously bump the rank.
    @Test func firstEverDumpCakeDoesNotFireARankUp() async {
        let dependencies = FakeFeedDependencies()  // no prior cooks
        let viewModel = FeedViewModel(dependencies: dependencies)
        guard let cake = DumpCake.all.first else {
            Issue.record("no dump cakes configured")
            return
        }

        await viewModel.logCook(makeCook(cake.id))  // 1st cook overall, but off-path

        #expect(viewModel.celebration == nil)
    }

    /// DUT-625 — dump-cake cooks are excluded from the rank ladder, so they
    /// don't inflate the count that a later PATH cook's rank-up is measured
    /// against: a first path cook still earns Fire Starter even after dump cakes.
    @Test func dumpCakesDoNotInflateTheRankLadderForPathCooks() async {
        let dependencies = FakeFeedDependencies()
        // Two dump cakes already logged — off-path, so the rank count is still 0.
        dependencies.cooks = DumpCake.all.prefix(2).map { makeCook($0.id) }
        let viewModel = FeedViewModel(dependencies: dependencies)

        // The first PATH cook is rank-ladder cook #1 -> Fire Starter (threshold 1).
        await viewModel.logCook(makeCook(GuidedCookout.firstCookout.recipeID))

        if case .rankUp(let rank) = viewModel.celebration {
            #expect(rank.title == "Fire Starter")
        } else {
            Issue.record("expected Fire Starter rank-up, got \(String(describing: viewModel.celebration))")
        }
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

    /// DUT-339 — a celebration earned while the cookout sheet is up must NOT
    /// present until that sheet dismisses (else iOS swallows the second sheet).
    @Test func celebrationIsHeldUntilTheCookoutSheetDismisses() async {
        let dependencies = FakeFeedDependencies()
        dependencies.cooks = [makeCook(9001), makeCook(9002)]
        let viewModel = FeedViewModel(dependencies: dependencies)

        viewModel.cookoutFlowWillPresent()
        await viewModel.logCook(makeCook(9003))  // crosses to Coal Tender while sheet is up

        #expect(viewModel.celebration == nil)  // held — sheet still dismissing

        viewModel.cookoutFlowDidDismiss()

        if case .rankUp(let rank) = viewModel.celebration {
            #expect(rank.title == "Coal Tender")
        } else {
            Issue.record("expected the held rank-up to present, got \(String(describing: viewModel.celebration))")
        }
    }

    /// DUT-339 — reverse ordering: the sheet dismisses BEFORE the async log
    /// resolves; the celebration must still present once the log completes.
    @Test func celebrationPromotesWhenLogCompletesAfterDismissal() async {
        let dependencies = FakeFeedDependencies()
        dependencies.cooks = [makeCook(9001), makeCook(9002)]
        let viewModel = FeedViewModel(dependencies: dependencies)

        viewModel.cookoutFlowWillPresent()
        viewModel.cookoutFlowDidDismiss()  // sheet gone before the log resolves
        #expect(viewModel.celebration == nil)  // nothing pending yet

        await viewModel.logCook(makeCook(9003))

        #expect(viewModel.celebration != nil)  // promotes on log completion
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
