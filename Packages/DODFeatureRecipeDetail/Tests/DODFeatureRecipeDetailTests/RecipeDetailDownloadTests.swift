import DODAnalytics
import DODDomain
import DODNetworking
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// US-35 — explicit download for offline use. L1 contract for the
/// `RecipeDetailViewModel.downloadForOffline()` path. Split from
/// `RecipeDetailViewModelTests.swift` so neither file trips SwiftLint's
/// `type_body_length` cap.
@MainActor
@Suite("RecipeDetailViewModel download (T-620)") struct RecipeDetailDownloadTests {

    @Test func downloadForOfflineMarksRecipeAndShowsSnackbar() async throws {
        // US-35 / AC-35.2 / AC-35.3 — first-time download flips
        // `isDownloaded` and surfaces the "Recipe downloaded for offline
        // use" snackbar copy.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 620,
            withDetail: true
        )
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 620)
        await viewModel.onAppear()
        #expect(viewModel.isDownloaded == false)

        await viewModel.downloadForOffline()

        #expect(viewModel.isDownloaded == true)
        #expect(viewModel.snackbarMessage == "Recipe downloaded for offline use")
        #expect(dependencies.downloadedIDs.contains(620))
    }

    @Test func downloadForOfflineAlsoSavesRecipe() async throws {
        // T-761 / CL-158 / AC-35.5 (DUT-67) — downloading a recipe also
        // SAVES it (download = save + offline pin): `isSaved` flips true
        // and the row is mirrored into the saved store. A previously
        // *unsaved* recipe still reports a first-time download.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 620,
            withDetail: true
        )
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 620)
        await viewModel.onAppear()
        #expect(viewModel.isSaved == false)

        await viewModel.downloadForOffline()

        #expect(viewModel.isSaved == true)
        #expect(dependencies.savedIDs.contains(620))
        #expect(viewModel.snackbarMessage == "Recipe downloaded for offline use")
    }

    @Test func downloadForOfflineOnSavedRecipeStillDownloadsFresh() async throws {
        // T-761 / CL-158 (DUT-67) — save and download are decoupled. A
        // merely-*saved* recipe (no prior `downloadedAt` pin) is NOT
        // treated as already-downloaded: tapping Download performs a
        // first-time download rather than short-circuiting to the
        // "Already downloaded" copy (the pre-T-761 CL-61 behavior).
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 621,
            withDetail: true
        )
        dependencies.savedIDs = [621]
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 621)
        await viewModel.onAppear()

        await viewModel.downloadForOffline()

        #expect(viewModel.isDownloaded == true)
        #expect(viewModel.snackbarMessage == "Recipe downloaded for offline use")
    }

    @Test func reDownloadSurfacesAlreadyDownloadedButKeepsSaved() async throws {
        // US-35 / AC-35.4 + T-761 / CL-158 — re-tapping Download on a
        // recipe that already has a real `downloadedAt` pin surfaces the
        // "Already downloaded" copy (no image re-fetch). "Downloaded
        // recipes still save": even on the already-downloaded path the
        // recipe is guaranteed saved (backfills the bookmark for a recipe
        // downloaded under the pre-T-761 behavior).
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 622,
            withDetail: true
        )
        dependencies.downloadedIDs = [622]
        #expect(dependencies.savedIDs.contains(622) == false)
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 622)
        await viewModel.onAppear()

        await viewModel.downloadForOffline()

        #expect(viewModel.isDownloaded == true)
        #expect(viewModel.snackbarMessage == "Already downloaded")
        #expect(viewModel.isSaved == true)
        #expect(dependencies.savedIDs.contains(622))
    }

    @Test func savingDoesNotDownloadRecipe() async throws {
        // T-761 / CL-158 / AC-35.6 (DUT-67) — the inverse half: tapping
        // Save is a lightweight favorite and must NOT download. After a
        // save the recipe is saved but `isDownloaded` stays false and no
        // download pin is recorded.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 623,
            withDetail: true
        )
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 623)
        await viewModel.onAppear()

        await viewModel.toggleSaved()

        #expect(viewModel.isSaved == true)
        #expect(viewModel.isDownloaded == false)
        #expect(dependencies.downloadedIDs.isEmpty)
        #expect(viewModel.snackbarMessage == "Saved.")
    }

    @Test func removeDownloadClearsStateButKeepsSaved() async throws {
        // T-775 / DUT-81 — the toolbar download button is a toggle: removing
        // a download flips `isDownloaded` back to false and surfaces "Download
        // removed", but must NOT unsave the recipe (save/download decoupled,
        // T-761) — so the card stays in the Saved tab, just without the badge.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 624, withDetail: true)
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 624)
        await viewModel.onAppear()
        await viewModel.downloadForOffline()
        #expect(viewModel.isDownloaded == true)
        #expect(viewModel.isSaved == true)

        await viewModel.removeDownload()

        #expect(viewModel.isDownloaded == false)
        #expect(viewModel.snackbarMessage == "Download removed")
        #expect(dependencies.downloadedIDs.contains(624) == false)
        // Un-download ≠ unsave.
        #expect(viewModel.isSaved == true)
        #expect(dependencies.savedIDs.contains(624))
    }

    @Test func toggleDownloadDispatchesBothDirections() async throws {
        // T-775 / DUT-81 — the toolbar button calls `toggleDownload()`; it must
        // download when not downloaded and remove when already downloaded.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 625, withDetail: true)
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 625)
        await viewModel.onAppear()
        #expect(viewModel.isDownloaded == false)

        await viewModel.toggleDownload()
        #expect(viewModel.isDownloaded == true)

        await viewModel.toggleDownload()
        #expect(viewModel.isDownloaded == false)
        #expect(viewModel.snackbarMessage == "Download removed")
    }

    @Test func toggleDownloadOfflineWarnsInsteadOfRemoving() async throws {
        // T-778 / DUT-84 — tapping the filled download button while OFFLINE must
        // not remove immediately: it raises the confirmation flag and leaves the
        // download intact (removing with no network would strand the recipe).
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 626, withDetail: true)
        dependencies.online = false
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 626)
        await viewModel.onAppear()
        await viewModel.downloadForOffline()
        #expect(viewModel.isDownloaded == true)

        await viewModel.toggleDownload()

        #expect(viewModel.showOfflineRemoveDownloadWarning == true)
        // Nothing removed yet — the download (and pin) survive until confirmed.
        #expect(viewModel.isDownloaded == true)
        #expect(dependencies.downloadedIDs.contains(626))
    }

    @Test func toggleDownloadOnlineRemovesWithoutWarning() async throws {
        // T-778 / DUT-84 — the online path is unchanged: removal is instant, no
        // confirmation (re-downloading is a tap away).
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 627, withDetail: true)
        dependencies.online = true
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 627)
        await viewModel.onAppear()
        await viewModel.downloadForOffline()

        await viewModel.toggleDownload()

        #expect(viewModel.showOfflineRemoveDownloadWarning == false)
        #expect(viewModel.isDownloaded == false)
        #expect(viewModel.snackbarMessage == "Download removed")
    }

    @Test func confirmRemoveDownloadRemovesAndClearsWarning() async throws {
        // T-778 / DUT-84 — confirming the offline warning ("Remove Download")
        // clears the flag and performs the removal; the recipe stays saved.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 628, withDetail: true)
        dependencies.online = false
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 628)
        await viewModel.onAppear()
        await viewModel.downloadForOffline()
        await viewModel.toggleDownload()
        #expect(viewModel.showOfflineRemoveDownloadWarning == true)

        await viewModel.confirmRemoveDownload()

        #expect(viewModel.showOfflineRemoveDownloadWarning == false)
        #expect(viewModel.isDownloaded == false)
        #expect(viewModel.snackbarMessage == "Download removed")
        #expect(dependencies.downloadedIDs.contains(628) == false)
        #expect(viewModel.isSaved == true)
    }

    private func makeViewModel(
        dependencies: RecipeDetailDependencies,
        listItemID: Int
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: listItemID),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(listItemID)/")
                ?? URL(filePath: "/"),
            dependencies: dependencies
        )
    }
}
