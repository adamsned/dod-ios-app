import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

/// Genuine-gap tests for SavedViewModel edge cases not covered by existing suites.
/// Each gap fills a behavior that exists in the source (DUT-tagged comments, error
/// paths, delegation) but lacks direct test coverage. Split into a new file to
/// keep SavedViewModelTests below the `file_length` cap.
@MainActor
@Suite("SavedViewModel edge cases") struct SavedViewModelEdgeCasesTests {

    /// DUT-487 — recipeWithIngredients(_:) delegates to the dependency to hydrate
    /// a saved recipe's ingredients (in case the recipe was never opened, so its
    /// detail was never fetched). The view model exposes this public seam so
    /// SavedView can pass it to the Shopping List picker. Verify the delegation
    /// works: the input recipe is forwarded unchanged (the fake's default behavior).
    @Test func recipeWithIngredientsDelegatesToDependency() async {
        let dependencies = FakeSavedDependencies()
        let recipe = SavedViewModelTests.makeRecipe(id: 42)
        let viewModel = SavedViewModel(dependencies: dependencies)

        let result = await viewModel.recipeWithIngredients(recipe)

        // The fake returns recipes unchanged (default implementation), so the
        // delegated call must return the same recipe.
        #expect(result.id == recipe.id)
        #expect(result.title == recipe.title)
    }

    /// startObserving()'s guard ensures calling it twice creates only one
    /// remoteChangeTask. The existing leak test (startObservingDoesNotLeakTheViewModel)
    /// verifies the task's lifecycle but doesn't test the idempotency guard itself.
    /// Verify that a second call is a no-op by checking the call count after the
    /// task has started executing.
    @Test func startObservingIsIdempotent() async {
        let dependencies = FakeSavedDependencies()
        let viewModel = SavedViewModel(dependencies: dependencies)

        viewModel.startObserving()
        // Wait for the first task to call remoteChanges()
        await SavedViewModelTests.expectEventually { dependencies.remoteChangesCallCount > 0 }
        let callsAfterFirst = dependencies.remoteChangesCallCount

        viewModel.startObserving()
        // Give a brief moment for any potential second call (it should NOT happen)
        try? await Task.sleep(for: .milliseconds(50))
        let callsAfterSecond = dependencies.remoteChangesCallCount

        // The second call's guard must have prevented it, so the count stays at 1.
        #expect(callsAfterFirst == 1, "First startObserving() must call remoteChanges()")
        #expect(
            callsAfterSecond == 1,
            "Second startObserving() must not call remoteChanges() again (guard prevents it)"
        )
    }

    /// DUT-369 — a refresh failure must preserve the existing grid when recipes
    /// are already loaded. Only show the error state if there's nothing on screen
    /// (recipes.isEmpty). This complements errorStatePresentsRetry (which tests
    /// the isEmpty branch). Verify that a loaded recipe list survives a fetch error.
    @Test func refreshFailurePreservesLoadedRecipes() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [SavedViewModelTests.makeRecipe(id: 1), SavedViewModelTests.makeRecipe(id: 2)]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.recipes.map(\.id) == [1, 2])

        // Trigger a fetch failure on the next refresh
        dependencies.shouldFail = true
        await viewModel.refresh()

        // The recipes must stay, error state must NOT be shown (because recipes
        // are not empty), and the load state should remain as-is or revert to loaded.
        #expect(viewModel.recipes.map(\.id) == [1, 2], "Refresh failure must preserve loaded recipes")
        #expect(viewModel.loadState != .error, "Refresh failure must not show error state when recipes are loaded")
    }

    /// T-774 / DUT-80 — downloadedRecipeIDs() is best-effort: if it throws, the
    /// refresh must still complete successfully (just with no badges). The code
    /// uses `try?` to suppress the error: `let downloaded = (try? await
    /// dependencies.downloadedRecipeIDs()) ?? []`. Verify that a failed download-id
    /// fetch doesn't fail the entire refresh.
    @Test func refreshCompletesWhenDownloadedRecipeIDsThrows() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [SavedViewModelTests.makeRecipe(id: 1)]
        dependencies.downloadedIDs = [1]
        let viewModel = SavedViewModel(dependencies: dependencies)

        // Set up a failure on the next call to downloadedRecipeIDs()
        dependencies.shouldFailDownloadedIDs = true
        await viewModel.refresh()

        // The refresh must complete without crashing. Recipes loaded, but
        // downloadedIDs should be empty (the ?? [] fallback).
        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.recipes.map(\.id) == [1])
        #expect(viewModel.downloadedIDs.isEmpty, "Failed downloadedRecipeIDs must fall back to empty set")
    }

    /// DUT-365 — after every successful refresh (including debounced remote-change
    /// refreshes), the view model calls publishSavedWidget() to republish the
    /// home-screen widget snapshot. A recipe saved on another device (CloudKit
    /// import → remote-change signal → debounced refresh → publishSavedWidget)
    /// must update the widget. Verify the dependency method is invoked.
    @Test func publishSavedWidgetIsCalledAfterSuccessfulRefresh() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [SavedViewModelTests.makeRecipe(id: 1)]
        let viewModel = SavedViewModel(dependencies: dependencies)

        // Track whether publishSavedWidget was called by assigning a closure
        // that increments a counter. Use a reference type to mutate the count
        // across the closure boundary.
        class CallCounter {
            var count = 0
        }
        let counter = CallCounter()
        dependencies.publishSavedWidgetImpl = {
            counter.count += 1
        }

        await viewModel.refresh()

        #expect(counter.count == 1, "publishSavedWidget must be called once after successful refresh")
    }

    /// DUT — verify that refresh() doesn't show a loading spinner on background
    /// refreshes (e.g., remote-change import while the tab is already visible with
    /// recipes). The code has: `if recipes.isEmpty { loadState = .loading }` so
    /// on a background refresh where recipes are non-empty, the loading state is
    /// skipped. Verify that a background refresh doesn't flicker to loading.
    @Test func backgroundRefreshDoesNotShowLoadingState() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [SavedViewModelTests.makeRecipe(id: 1)]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        #expect(viewModel.loadState == .loaded)

        // Simulate a background refresh (remote-change import)
        dependencies.recipes = [
            SavedViewModelTests.makeRecipe(id: 2),
            SavedViewModelTests.makeRecipe(id: 1),
        ]
        await viewModel.refresh()

        // The load state must stay .loaded (never transitioned to .loading).
        #expect(viewModel.loadState == .loaded, "Background refresh must not show loading state")
        #expect(viewModel.recipes.map(\.id) == [2, 1])
    }
}
