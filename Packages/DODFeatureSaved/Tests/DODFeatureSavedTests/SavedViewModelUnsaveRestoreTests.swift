import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

/// DUT-736 — the failed-unsave restore path. On a failed unsave the recipe is
/// still saved, and the bare DUT-629 restore `refresh()` cannot un-hide it:
/// within the optimistic-removal TTL the suppression re-applies and strips the
/// card back out. Clearing the suppression first (`clearPendingRemoval`, which
/// the failure path now does) brings the still-saved card back at once. Split
/// out — reusing `SavedViewModelTests`' `FakeSavedDependencies` + `makeRecipe` —
/// to keep that suite under the SwiftLint `file_length` cap, mirroring
/// `SavedViewModelDownloadWarningTests`.
@MainActor
@Suite("SavedViewModel failed-unsave restore (DUT-736)")
struct SavedViewModelUnsaveRestoreTests {

    @Test func clearPendingRemovalUnhidesAStillSavedCardThatRefreshAloneCannot() async {
        let dependencies = FakeSavedDependencies()
        // The recipe stays saved throughout — i.e. the unsave write "failed".
        dependencies.recipes = [SavedViewModelTests.makeRecipe(id: 1)]

        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        #expect(viewModel.recipes.map(\.id) == [1])

        // Optimistic unsave hides the card; the store write then fails, so the
        // dependency keeps returning the recipe (with its original save time).
        viewModel.optimisticallyRemove(id: 1)
        #expect(viewModel.recipes.isEmpty)

        // The bare DUT-629 restore refresh can't un-hide it: still within the
        // TTL, the suppression re-applies and strips the card back out.
        await viewModel.refresh()
        #expect(viewModel.recipes.isEmpty)

        // DUT-736: clearing the suppression first (the failure-path fix) makes
        // the still-saved card reappear immediately.
        viewModel.clearPendingRemoval(id: 1)
        await viewModel.refresh()
        #expect(viewModel.recipes.map(\.id) == [1])
    }
}
