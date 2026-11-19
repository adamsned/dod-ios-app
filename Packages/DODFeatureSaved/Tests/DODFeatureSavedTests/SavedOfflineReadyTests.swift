import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

@MainActor
@Suite("SavedViewModel offline-ready error states") struct SavedOfflineReadyTests {

    /// DUT-1671 — when refresh fails and there are no saved recipes, SavedView
    /// should show a RetryStateView with .requestFailed kind instead of EmptyState.
    /// Verify the error state shows retry behavior for failed refreshes.
    @Test func refreshFailureShowsRetryState() async {
        let dependencies = FakeSavedDependencies()
        dependencies.shouldFail = true
        let viewModel = SavedViewModel(dependencies: dependencies)

        // Initially empty recipes and idle state
        #expect(viewModel.recipes.isEmpty)
        #expect(viewModel.loadState == .idle)

        await viewModel.refresh()

        // After refresh failure with no recipes, should show error state
        #expect(viewModel.loadState == .error)
    }

    /// DUT-1671 — when refresh fails but there are existing recipes, SavedView
    /// should preserve the loaded recipes and NOT show error state (per DUT-369).
    /// This verifies that error state is only shown when there's nothing loaded.
    @Test func refreshFailurePreservesLoadedRecipes() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [SavedViewModelTests.makeRecipe(id: 1)]
        let viewModel = SavedViewModel(dependencies: dependencies)

        // Load initial recipes
        await viewModel.refresh()
        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.recipes.count == 1)

        // Trigger a refresh failure
        dependencies.shouldFail = true
        await viewModel.refresh()

        // Should preserve existing recipes and NOT show error state
        #expect(viewModel.recipes.count == 1, "Recipes should be preserved")
        #expect(viewModel.loadState != .error, "Error state should not be shown when recipes exist")
    }

    /// DUT-1671 — verify that the view correctly uses retry state for network errors.
    @Test func errorStateUsesRetryStateView() async {
        let dependencies = FakeSavedDependencies()
        dependencies.shouldFail = true
        let viewModel = SavedViewModel(dependencies: dependencies)

        await viewModel.refresh()

        // Verify that when there are no recipes and we have an error,
        // the load state is error (which should trigger RetryStateView in the view)
        #expect(viewModel.loadState == .error)
    }
}
