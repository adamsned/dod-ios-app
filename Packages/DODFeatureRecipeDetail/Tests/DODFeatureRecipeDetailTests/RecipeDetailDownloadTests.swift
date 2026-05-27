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

    @Test func downloadForOfflineSurfacesAlreadyDownloadedSnackbarWhenSaved() async throws {
        // US-35 / AC-35.3 / CL-61 — re-tapping on a saved recipe (whose
        // AC-5.2 auto-download has already pinned the bytes) surfaces
        // the "Already downloaded" snackbar copy rather than the
        // first-time confirmation.
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
        #expect(viewModel.snackbarMessage == "Already downloaded")
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
