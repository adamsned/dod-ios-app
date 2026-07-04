import DODDomain
import Foundation
import Testing

@testable import DODFeatureSaved

/// DUT-229 — "Remove Download" on the Saved tab removes immediately whether the
/// device is online OR offline. The old DUT-84 offline confirmation guarded a
/// non-existent risk: `removeDownload` only clears the `downloadedAt` pin (the
/// recipe stays saved with its cached text + pinned hero), so the recipe still
/// opens offline afterward — nothing is stranded, so there is nothing to warn
/// about. Split from `SavedViewModelTests` so neither suite trips the
/// `type_body_length` cap. Reuses that suite's `FakeSavedDependencies` and
/// `makeRecipe` helper.
@MainActor
@Suite("SavedViewModel remove-download (DUT-229)") struct SavedViewModelDownloadWarningTests {

    @Test func requestRemoveDownloadOfflineRemovesImmediately() async {
        // DUT-229 — offline is NO different from online: removal is instant and
        // strands nothing (the saved recipe stays openable offline). The old
        // behavior stashed a pending id and presented a false warning; that is
        // gone.
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [SavedViewModelTests.makeRecipe(id: 1), SavedViewModelTests.makeRecipe(id: 2)]
        dependencies.downloadedIDs = [1, 2]
        dependencies.online = false
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()

        await viewModel.requestRemoveDownload(id: 1)

        // The badge clears optimistically and the write routes through even
        // offline; the card stays (un-download is not unsave).
        #expect(viewModel.downloadedIDs == [2])
        #expect(dependencies.removedDownloadIDs == [1])
        #expect(viewModel.recipes.map(\.id) == [1, 2])
    }

    @Test func requestRemoveDownloadOnlineRemovesImmediately() async {
        // Online, removal is instant: the badge clears optimistically and the
        // write routes through, exactly as offline.
        let dependencies = FakeSavedDependencies()
        dependencies.recipes = [SavedViewModelTests.makeRecipe(id: 1), SavedViewModelTests.makeRecipe(id: 2)]
        dependencies.downloadedIDs = [1, 2]
        dependencies.online = true
        let viewModel = SavedViewModel(dependencies: dependencies)
        await viewModel.refresh()

        await viewModel.requestRemoveDownload(id: 1)

        #expect(viewModel.downloadedIDs == [2])
        #expect(dependencies.removedDownloadIDs == [1])
    }
}
