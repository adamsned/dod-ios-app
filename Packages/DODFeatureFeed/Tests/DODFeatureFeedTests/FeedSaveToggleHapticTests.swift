import DODDomain
import Foundation
import Testing

@testable import DODFeatureFeed

// DUT — the Feed card Save/Unsave `.selection` haptic must fire ONLY on a genuine
// user toggle (keyed to `saveToggleCount`), never on the appear/refresh
// reconciliation of the saved-id `Set` (which reassigns `savedRecipeIDs` on load)
// nor on a failed-write rollback. Mirrors Categories' DUT-697 fix. Split into its
// own file to keep `FeedViewModelTests.swift` under the SwiftLint 400-line cap;
// reuses that suite's `FakeFeedDependencies` + `makeItem` (module-internal).
@MainActor
@Suite("FeedViewModel save-toggle haptic (DUT)") struct FeedSaveToggleHapticTests {

    @Test func saveToggleCountFiresOnlyOnGenuineToggleNotOnAppearOrRefresh() async {
        let dependencies = FakeFeedDependencies()
        dependencies.pages[1] = (1...5).map(FeedViewModelTests.makeItem)
        dependencies.savedIDs = [1, 3]  // a populated set to reconcile on appear
        let viewModel = FeedViewModel(dependencies: dependencies)

        // Appear hydrates the (non-empty) saved set but must not fire the haptic.
        await viewModel.onAppear()
        #expect(viewModel.savedRecipeIDs == [1, 3])
        #expect(viewModel.saveToggleCount == 0)

        // Reconciling the saved-id set from the store (the appear/re-open path
        // that reassigns `savedRecipeIDs`, picking up an out-of-band save) must
        // not fire the save haptic.
        dependencies.savedIDs = [1, 3, 5]
        await viewModel.refreshSavedRecipeIDs()
        #expect(viewModel.savedRecipeIDs == [1, 3, 5])
        #expect(viewModel.saveToggleCount == 0)

        // A pull-to-refresh (feed reload) likewise never fires the save haptic.
        await viewModel.refresh()
        #expect(viewModel.saveToggleCount == 0)

        // Only a genuine user toggle bumps the count.
        viewModel.applyOptimisticSaveToggle(id: 5)  // unsave → [1, 3]
        #expect(viewModel.saveToggleCount == 1)
        viewModel.applyOptimisticSaveToggle(id: 2)  // save → [1, 2, 3]
        #expect(viewModel.saveToggleCount == 2)

        // A failed-write rollback re-inverts the just-applied save (→ [1, 3]) but
        // stays silent — the counter must not advance on the revert.
        viewModel.revertOptimisticSaveToggle(id: 2)
        #expect(viewModel.savedRecipeIDs == [1, 3])
        #expect(viewModel.saveToggleCount == 2)
    }
}
