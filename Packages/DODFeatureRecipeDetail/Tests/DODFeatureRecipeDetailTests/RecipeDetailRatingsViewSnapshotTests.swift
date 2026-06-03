#if canImport(UIKit)
import DODDomain
import DODFeatureProfile
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODFeatureRecipeDetail

/// L4 visual-regression coverage for ``RecipeDetailRatingsSection``.
///
/// These tests pin the contract that the section header is always
/// rendered once the view model reaches `.ready`, and that the inner
/// content collapses gracefully to an "empty" affordance rather than
/// disappearing — the user-facing bug that motivated this regression
/// bundle.
///
/// First run with `isRecording = false` to create baselines, then revert
/// and commit. Subsequent runs diff against the baselines.
///
/// Spec trace: constitution §6 L4, US-13/14/15.
final class RecipeDetailRatingsViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Flip to true locally to refresh baselines after an intentional
        // visual change, then revert before commit.
        isRecording = false
    }

    @MainActor
    func test_section_emptyState_renders() async {
        // No rating, no comments — REG-14 zero summary path.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 901, withDetail: true)
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 901)
        await viewModel.onAppear()

        let view = RecipeDetailRatingsSection(viewModel: viewModel)
            .frame(width: 390)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    @MainActor
    func test_section_loadedState_renders() async {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 902, withDetail: true)
        dependencies.fetchedRatingSummary = RecipeRating(recipeID: 902, average: 4.5, count: 27)
        dependencies.fetchedComments = [
            RecipeDetailTestFixtures.makeComment(id: 11, postID: 902, body: "Made it twice — perfect."),
            RecipeDetailTestFixtures.makeComment(id: 12, postID: 902, body: "Family hit."),
        ]
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 902)
        await viewModel.onAppear()

        let view = RecipeDetailRatingsSection(viewModel: viewModel)
            .frame(width: 390)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    @MainActor
    func test_section_emptyAuthorFields_rendersOnForm() async {
        // DUT-28: with no saved guest identity, the section renders the
        // on-form "Display name" + "Email" fields empty (no pop-up) alongside
        // the star input + comment box. Pins that the identity now lives on
        // the form rather than behind a gate.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 903, withDetail: true)
        dependencies.fetchedRatingSummary = RecipeRating(recipeID: 903, average: 3.8, count: 5)
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 903)
        await viewModel.onAppear()
        viewModel.setPendingRating(4)

        XCTAssertTrue(viewModel.commentAuthorName.isEmpty, "No saved identity → name field empty")
        XCTAssertFalse(viewModel.isAuthorIdentityValid, "Empty identity is not yet valid")

        let view = RecipeDetailRatingsSection(viewModel: viewModel)
            .frame(width: 390)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    @MainActor
    func test_section_preFilledAuthorFields_renders() async {
        // DUT-28: a returning commenter's saved identity pre-fills the
        // on-form fields. Pins the populated layout.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 904, withDetail: true)
        dependencies.fetchedRatingSummary = RecipeRating(recipeID: 904, average: 3.8, count: 5)
        dependencies.guestIdentity = (name: "Jamie L.", email: "jamie@example.com")
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 904)
        await viewModel.onAppear()

        XCTAssertEqual(viewModel.commentAuthorName, "Jamie L.")
        XCTAssertTrue(viewModel.isAuthorIdentityValid)

        let view = RecipeDetailRatingsSection(viewModel: viewModel)
            .frame(width: 390)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    // MARK: - Phase c (T-741 / CL-138) — profile gate

    @MainActor
    func test_section_gatedState_renders() async {
        // AC-44.10: when `hasProfile == false`, the write composer is
        // blurred + overlaid with the `RatingsProfileGate` popup. The
        // existing reviews list (`commentsList`) stays readable below
        // the divider (AC-44.11).
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 905, withDetail: true)
        dependencies.fetchedRatingSummary = RecipeRating(recipeID: 905, average: 4.2, count: 9)
        dependencies.fetchedComments = [
            RecipeDetailTestFixtures.makeComment(id: 21, postID: 905, body: "Loved it — exactly what I needed.")
        ]
        dependencies.profileToLoad = nil  // The gate's trigger condition.
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 905)
        await viewModel.onAppear()

        XCTAssertFalse(viewModel.hasProfile, "No profile → composer must be gated")

        let view = RecipeDetailRatingsSection(viewModel: viewModel)
            .frame(width: 390)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    @MainActor
    func test_section_ungatedState_renders() async {
        // AC-44.10: when `hasProfile == true`, the gate collapses and
        // the composer is interactive — byte-identical to the pre-
        // Phase-c layout (the `gatedRateAndReviewCard` ZStack collapses
        // to just the composer view with no overlay or blur).
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 906, withDetail: true)
        dependencies.fetchedRatingSummary = RecipeRating(recipeID: 906, average: 4.2, count: 9)
        dependencies.fetchedComments = [
            RecipeDetailTestFixtures.makeComment(id: 22, postID: 906, body: "Loved it — exactly what I needed.")
        ]
        dependencies.profileToLoad = UserProfile(
            id: UUID(),
            displayName: "Spencer",
            email: "spencer@example.com",
            photoFilename: nil
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 906)
        await viewModel.onAppear()

        XCTAssertTrue(viewModel.hasProfile, "Profile populated → composer must be interactive")

        let view = RecipeDetailRatingsSection(viewModel: viewModel)
            .frame(width: 390)
        assertSnapshot(of: view, as: .image(layout: .sizeThatFits))
    }

    // MARK: - Helpers

    @MainActor
    static func makeViewModel(
        dependencies: RecipeDetailDependencies,
        listItemID: Int
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: listItemID),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(listItemID)/") ?? URL(filePath: "/"),
            dependencies: dependencies
        )
    }
}
#endif
