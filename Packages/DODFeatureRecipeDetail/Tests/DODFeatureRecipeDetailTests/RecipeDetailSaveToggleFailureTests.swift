import DODAnalytics
import DODDomain
import DODNetworking
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// A thrown `toggleSaved(id:)` (e.g. a `modelContext.save()` failure in the
/// live store) must not leave the Save-button tap silent. Split out of
/// `RecipeDetailViewModelTests.swift` so that file stays under SwiftLint's
/// `type_body_length` cap (mirrors `RecipeDetailDownloadTests.swift`).
@MainActor
@Suite("RecipeDetailViewModel.toggleSaved failure") struct RecipeDetailSaveToggleFailureTests {

    @Test func toggleSavedFailureSurfacesSnackbarWithoutFlippingState() async throws {
        // `isSaved` stays whatever it was before the tap (no false flip), but
        // the user still needs to be told the tap didn't land — mirrors
        // `downloadForOffline()` / `removeDownload()` in
        // `RecipeDetailViewModel+Download.swift`, which both set a
        // "Couldn't ... — try again." snackbar on catch.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 5, withDetail: true)
        dependencies.toggleSavedShouldFail = true
        let viewModel = makeViewModel(dependencies: dependencies, listItemID: 5)
        await viewModel.onAppear()
        #expect(viewModel.isSaved == false)

        await viewModel.toggleSaved()

        #expect(viewModel.isSaved == false, "A failed toggle must not report a state change that never landed")
        #expect(viewModel.snackbarMessage != nil, "A failed save tap must tell the user it didn't land")
        #expect(
            !dependencies.telemetryEvents.contains { event in
                if case .recipeSaved = event { return true }
                return false
            },
            "A failed store write must not fire the recipeSaved success telemetry"
        )
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
