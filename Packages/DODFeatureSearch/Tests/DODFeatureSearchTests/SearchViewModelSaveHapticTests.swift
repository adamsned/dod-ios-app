import DODDomain
import Foundation
import Testing

@testable import DODFeatureSearch

@MainActor
@Suite("SearchViewModel save haptic (DUT)") struct SearchViewModelSaveHapticTests {

    /// Mirrors Categories' `saveToggleCountFiresOnlyOnGenuineToggleNotOnAppearOrRefresh`.
    /// The `.selection` save haptic must fire ONLY on a genuine long-press
    /// Save/Unsave — never on appear/refresh reconciliation of the saved-id set
    /// (which reassigns `savedRecipeIDs` and would mis-fire if the haptic were
    /// keyed to the set), and never on a failed-write rollback.
    @Test func saveToggleCountFiresOnlyOnGenuineToggleNotOnAppearOrRefresh() async {
        let dependencies = FakeSearchDependencies()
        dependencies.savedIDs = [1, 3]  // a populated set to reconcile on appear
        let viewModel = SearchViewModel(
            dependencies: dependencies,
            recentSearches: SearchViewModelTests.scratchRecents()
        )

        // Appear reconciliation hydrates the (non-empty) set but must not buzz.
        await viewModel.refreshSavedRecipeIDs()
        #expect(viewModel.savedRecipeIDs == [1, 3])
        #expect(viewModel.saveToggleCount == 0)

        // A later refresh that picks up an out-of-band save must not buzz either.
        dependencies.savedIDs = [1, 3, 5]
        await viewModel.refreshSavedRecipeIDs()
        #expect(viewModel.savedRecipeIDs == [1, 3, 5])
        #expect(viewModel.saveToggleCount == 0)

        // Only a genuine user toggle bumps the count.
        viewModel.applyOptimisticSaveToggle(id: 5)  // unsave
        #expect(viewModel.saveToggleCount == 1)
        viewModel.applyOptimisticSaveToggle(id: 2)  // save
        #expect(viewModel.saveToggleCount == 2)

        // A failed-write rollback re-inverts membership silently (no haptic).
        viewModel.revertOptimisticSaveToggle(id: 2)
        #expect(viewModel.savedRecipeIDs.contains(2) == false)
        #expect(viewModel.saveToggleCount == 2)
    }
}
