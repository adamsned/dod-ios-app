import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("RecipeDetailViewModel.submitGuestReaction — DUT-2067")
struct RecipeDetailGuestReactionTests {

    private static func makeViewModel(
        dependencies: FakeRecipeDetailDependencies,
        listItemID: Int,
        email: String = "ned@example.com"
    ) async -> RecipeDetailViewModel {
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: listItemID, withDetail: true)
        dependencies.guestIdentity = (name: "Ned", email: email)
        let viewModel = RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: listItemID),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(listItemID)/") ?? URL(filePath: "/"),
            dependencies: dependencies
        )
        await viewModel.onAppear()
        return viewModel
    }

    @Test func successPostsAttributedBodyAndRating() async {
        let dependencies = FakeRecipeDetailDependencies()
        let viewModel = await Self.makeViewModel(dependencies: dependencies, listItemID: 90)

        let ok = await viewModel.submitGuestReaction(quote: "Best ribs ever", guestName: "Sam", rating: 5)

        #expect(ok)
        #expect(dependencies.lastPostCommentNameEmail?.email == "ned@example.com")
        let posted = viewModel.comments.first
        #expect(posted?.body.contains("Sam") == true)
        #expect(posted?.body.contains("Best ribs ever") == true)
        #expect(posted?.ratingValue == 5)
    }

    @Test func missingEmailReturnsFalseAndPostsNothing() async {
        let dependencies = FakeRecipeDetailDependencies()
        let viewModel = await Self.makeViewModel(dependencies: dependencies, listItemID: 91, email: "   ")

        let ok = await viewModel.submitGuestReaction(quote: "Great", guestName: "Sam", rating: 4)

        #expect(ok == false)
        #expect(dependencies.lastPostCommentNameEmail == nil)
    }

    @Test func blankQuoteReturnsFalseAndPostsNothing() async {
        let dependencies = FakeRecipeDetailDependencies()
        let viewModel = await Self.makeViewModel(dependencies: dependencies, listItemID: 92)

        let ok = await viewModel.submitGuestReaction(quote: "   ", guestName: "Sam", rating: 4)

        #expect(ok == false)
        #expect(dependencies.lastPostCommentNameEmail == nil)
    }
}
