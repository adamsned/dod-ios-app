import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

@MainActor
@Suite("SavedViewModel (T-130..T-136)") struct SavedViewModelTests {

    @Test func emptyStateWhenNoSaves() async {
        let dependencies = FakeSavedDependencies()
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        #expect(viewModel.loadState == .empty)
    }

    @Test func loadedStatePresentsRecipesNewestFirst() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [
            Self.makeRecipe(id: 2),
            Self.makeRecipe(id: 1),
        ]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        #expect(viewModel.loadState == .loaded)
        #expect(viewModel.recipes.map(\.id) == [2, 1])
    }

    @Test func refreshHydratesDownloadedIDsForBadging() async {
        // T-774 / DUT-80 — the Saved tab badges cards that are saved AND
        // downloaded; the view model hydrates the downloaded-id set alongside
        // the recipes so `SavedView` can check membership per card.
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [Self.makeRecipe(id: 1), Self.makeRecipe(id: 2), Self.makeRecipe(id: 3)]
        dependencies.downloadedIDs = [1, 3]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        #expect(viewModel.downloadedIDs == [1, 3])
    }

    @Test func removeDownloadClearsBadgeOptimisticallyAndRoutesStoreWrite() async {
        // T-775 / DUT-81 — the Saved-tab "Remove Download" action clears the
        // card's "Downloaded" badge instantly (optimistic `downloadedIDs`
        // update) and routes the un-download through the dependency. The
        // recipe stays in `recipes` (un-download ≠ unsave).
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [Self.makeRecipe(id: 1), Self.makeRecipe(id: 2)]
        dependencies.downloadedIDs = [1, 2]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        #expect(viewModel.downloadedIDs == [1, 2])

        await viewModel.removeDownload(id: 1)

        #expect(viewModel.downloadedIDs == [2])
        #expect(dependencies.removedDownloadIDs == [1])
        // The card itself stays — only the badge cleared (un-download ≠ unsave).
        #expect(viewModel.recipes.map(\.id) == [1, 2])
    }

    @Test func errorStatePresentsRetry() async {
        let dependencies = FakeSavedDependencies()
        dependencies.shouldFail = true
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        #expect(viewModel.loadState == .error)
        dependencies.shouldFail = false
        dependencies.recipes = [Self.makeRecipe(id: 9)]
        await viewModel.refresh()
        #expect(viewModel.loadState == .loaded)
    }

    // T-635 / CL-104 — optimistic removal so the Saved-tab card disappears
    // instantly on Unsave, without waiting for the next `.task` cycle.

    @Test func optimisticallyRemoveStripsMatchingRecipe() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [
            Self.makeRecipe(id: 1),
            Self.makeRecipe(id: 2),
            Self.makeRecipe(id: 3),
        ]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        #expect(viewModel.loadState == .loaded)

        viewModel.optimisticallyRemove(id: 2)

        #expect(viewModel.recipes.map(\.id) == [1, 3])
        #expect(viewModel.loadState == .loaded)
    }

    @Test func optimisticallyRemoveTransitionsToEmptyWhenLastRecipeRemoved() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [Self.makeRecipe(id: 7)]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        #expect(viewModel.loadState == .loaded)

        viewModel.optimisticallyRemove(id: 7)

        #expect(viewModel.recipes.isEmpty)
        #expect(viewModel.loadState == .empty)
    }

    @Test func optimisticallyRemoveIgnoresUnknownId() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [Self.makeRecipe(id: 1), Self.makeRecipe(id: 2)]
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        let before = viewModel.recipes.map(\.id)

        viewModel.optimisticallyRemove(id: 999)

        #expect(viewModel.recipes.map(\.id) == before)
        #expect(viewModel.loadState == .loaded)
    }

    // DUT-6 — the Saved tab must re-fetch when CloudKit imports a recipe
    // saved on another device, instead of staying stale until relaunch. The
    // view model subscribes to `dependencies.remoteChanges()`; firing a
    // synthetic signal through the fake must drive `savedRecipes()` again and
    // surface the newly-arrived recipe.

    @Test func remoteChangeSignalTriggersRefetch() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [Self.makeRecipe(id: 1)]
        let viewModel = SavedViewModel(dependencies: dependencies)

        viewModel.startObserving()
        await viewModel.refresh()
        #expect(viewModel.recipes.map(\.id) == [1])

        // Simulate the remote import: a second recipe lands in the store on
        // another device, then the CloudKit mirror posts a remote-change.
        dependencies.recipes = [Self.makeRecipe(id: 2), Self.makeRecipe(id: 1)]
        dependencies.fireRemoteChange()

        await Self.expectEventually { viewModel.recipes.map(\.id) == [2, 1] }
        #expect(viewModel.loadState == .loaded)
    }

    @Test func remoteChangeRefetchSurfacesEmptyStateAfterRemoteUnsave() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [Self.makeRecipe(id: 1)]
        let viewModel = SavedViewModel(dependencies: dependencies)

        viewModel.startObserving()
        await viewModel.refresh()
        #expect(viewModel.loadState == .loaded)

        // The other device unsaved the last recipe; the import empties the
        // store, and the re-fetch must transition to the empty state.
        dependencies.recipes = []
        dependencies.fireRemoteChange()

        await Self.expectEventually { viewModel.loadState == .empty }
        #expect(viewModel.recipes.isEmpty)
    }

    @Test func remoteChangeBurstCoalescesIntoOneRefetch() async {
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [Self.makeRecipe(id: 1)]
        let viewModel = SavedViewModel(dependencies: dependencies)

        viewModel.startObserving()
        await viewModel.refresh()
        // The appear-time refresh is the only call so far.
        #expect(dependencies.savedRecipesCallCount == 1)

        // CloudKit commonly imports several record zones back-to-back. Fire a
        // burst; the debounce must collapse it to a single re-fetch.
        dependencies.recipes = [Self.makeRecipe(id: 2), Self.makeRecipe(id: 1)]
        for _ in 0..<8 {
            dependencies.fireRemoteChange()
        }

        await Self.expectEventually { viewModel.recipes.map(\.id) == [2, 1] }
        // 1 appear-time refresh + exactly 1 debounced refresh for the burst.
        #expect(dependencies.savedRecipesCallCount == 2)
    }

    /// Poll `condition` on the main actor until it holds or the timeout
    /// elapses. The remote-change path debounces with a real `Task.sleep`, so
    /// tests await the resulting state rather than a fixed delay (avoids both
    /// flakiness and over-sleeping). Default budget comfortably exceeds the
    /// 300ms debounce.
    static func expectEventually(
        timeout: Duration = .seconds(2),
        _ condition: @MainActor () -> Bool
    ) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition(), "condition did not become true within \(timeout)")
    }

    static func makeRecipe(id: Int) -> Recipe {
        Recipe(
            id: id,
            slug: "s\(id)",
            title: "Title \(id)",
            excerpt: "Excerpt",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/\(id)/") ?? URL(filePath: "/"),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: [.init(text: "salt")],
            instructions: [.init(step: 1, text: "Mix.")]
        )
    }
}

final class FakeSavedDependencies: SavedDependencies, @unchecked Sendable {
    var recipes: [Recipe] = []
    var shouldFail = false
    var preDownloadedRecipeIDs: [Int] = []
    /// T-774 / DUT-80 — the set ``downloadedRecipeIDs()`` returns, so a test can
    /// assert the view model hydrates `downloadedIDs` for the Saved-tab badge.
    var downloadedIDs: Set<Int> = []
    /// T-775 / DUT-81 — recipe ids the view model asked to un-download, so a
    /// test can assert the store write routed through the dependency.
    var removedDownloadIDs: [Int] = []
    /// Number of times ``savedRecipes()`` has been called — lets a test assert
    /// the view model coalesces a remote-change burst into a single re-fetch.
    private(set) var savedRecipesCallCount = 0

    /// Synthetic remote-change trigger (DUT-6). The view model subscribes to
    /// ``remoteChanges()``; a test calls ``fireRemoteChange()`` to simulate a
    /// CloudKit import landing, then asserts the view model re-fetched.
    private let remoteChangeStream: AsyncStream<Void>
    private let remoteChangeContinuation: AsyncStream<Void>.Continuation

    init() {
        (remoteChangeStream, remoteChangeContinuation) = AsyncStream.makeStream()
    }

    func savedRecipes() async throws -> [Recipe] {
        savedRecipesCallCount += 1
        if shouldFail { throw URLError(.unknown) }
        return recipes
    }

    func downloadedRecipeIDs() async throws -> Set<Int> { downloadedIDs }

    func removeDownload(id: Int) async throws {
        removedDownloadIDs.append(id)
        downloadedIDs.remove(id)
    }

    func preDownloadImages(forRecipeID recipeID: Int, urls: [URL]) async {
        preDownloadedRecipeIDs.append(recipeID)
    }

    func remoteChanges() -> AsyncStream<Void> {
        remoteChangeStream
    }

    /// Simulate one CloudKit remote-import signal reaching the view model.
    func fireRemoteChange() {
        remoteChangeContinuation.yield(())
    }
}
