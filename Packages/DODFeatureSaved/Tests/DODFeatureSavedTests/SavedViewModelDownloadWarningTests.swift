import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

/// T-778 / DUT-84 — the offline remove-download confirmation on the Saved tab.
/// Split from `SavedViewModelTests` so neither suite trips the
/// `type_body_length` cap. Reuses that suite's `FakeSavedDependencies` and
/// `makeRecipe` helper.
@MainActor
@Suite("SavedViewModel offline remove-download (T-778)") struct SavedViewModelDownloadWarningTests {

    @Test func requestRemoveDownloadOfflineStashesPendingWithoutRemoving() async {
        // Offline, "Remove Download" must not remove immediately: it stashes the
        // id for confirmation and leaves the badge + store pin intact (removing
        // with no network strands the recipe).
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [SavedViewModelTests.makeRecipe(id: 1), SavedViewModelTests.makeRecipe(id: 2)]
        dependencies.downloadedIDs = [1, 2]
        dependencies.online = false
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()

        await viewModel.requestRemoveDownload(id: 1)

        #expect(viewModel.pendingOfflineRemoveDownloadID == 1)
        #expect(viewModel.downloadedIDs == [1, 2])
        #expect(dependencies.removedDownloadIDs.isEmpty)
    }

    @Test func requestRemoveDownloadOnlineRemovesImmediately() async {
        // Online, removal stays instant (no confirmation): the badge clears
        // optimistically and the write routes through, exactly as pre-DUT-84.
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [SavedViewModelTests.makeRecipe(id: 1), SavedViewModelTests.makeRecipe(id: 2)]
        dependencies.downloadedIDs = [1, 2]
        dependencies.online = true
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()

        await viewModel.requestRemoveDownload(id: 1)

        #expect(viewModel.pendingOfflineRemoveDownloadID == nil)
        #expect(viewModel.downloadedIDs == [2])
        #expect(dependencies.removedDownloadIDs == [1])
    }

    @Test func confirmPendingRemoveDownloadRemovesAndClearsPending() async {
        // Confirming the offline warning removes the stashed download and clears
        // the pending id; the card stays (un-download is not unsave).
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [SavedViewModelTests.makeRecipe(id: 1), SavedViewModelTests.makeRecipe(id: 2)]
        dependencies.downloadedIDs = [1, 2]
        dependencies.online = false
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        await viewModel.requestRemoveDownload(id: 1)
        #expect(viewModel.pendingOfflineRemoveDownloadID == 1)

        await viewModel.confirmPendingRemoveDownload()

        #expect(viewModel.pendingOfflineRemoveDownloadID == nil)
        #expect(viewModel.downloadedIDs == [2])
        #expect(dependencies.removedDownloadIDs == [1])
        #expect(viewModel.recipes.map(\.id) == [1, 2])
    }

    @Test func cancelPendingRemoveDownloadKeepsTheDownload() async {
        // "Keep Download" dismisses without removing.
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [SavedViewModelTests.makeRecipe(id: 1)]
        dependencies.downloadedIDs = [1]
        dependencies.online = false
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()
        await viewModel.requestRemoveDownload(id: 1)
        #expect(viewModel.pendingOfflineRemoveDownloadID == 1)

        viewModel.cancelPendingRemoveDownload()

        #expect(viewModel.pendingOfflineRemoveDownloadID == nil)
        #expect(viewModel.downloadedIDs == [1])
        #expect(dependencies.removedDownloadIDs.isEmpty)
    }
}
