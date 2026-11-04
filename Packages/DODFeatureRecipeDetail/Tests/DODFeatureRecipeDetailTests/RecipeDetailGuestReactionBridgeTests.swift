import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("Cook Mode guest-reaction bridge — DUT-2071")
struct RecipeDetailGuestReactionBridgeTests {

    @Test func nilRatingPostsAttributedCommentOnce() async {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 95, withDetail: true)
        dependencies.guestIdentity = (name: "Ned", email: "ned@example.com")
        let viewModel = RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: 95),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/95/") ?? URL(filePath: "/"),
            dependencies: dependencies
        )
        await viewModel.onAppear()

        let ok = await viewModel.submitGuestReaction(quote: "Wow", guestName: "Pat", rating: nil)

        #expect(ok)
        #expect(dependencies.lastPostCommentNameEmail?.email == "ned@example.com")
        #expect(viewModel.comments.count == 1)
        #expect(viewModel.comments.first?.body.contains("Pat") == true)
        #expect(viewModel.comments.first?.ratingValue == nil)
    }
}
