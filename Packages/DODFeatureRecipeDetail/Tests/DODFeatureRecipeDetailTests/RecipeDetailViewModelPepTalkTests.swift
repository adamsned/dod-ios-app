import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-985 — the first-cook pep talk gate on ``RecipeDetailViewModel``.
@MainActor
@Suite("RecipeDetailViewModel pep talk gate (DUT-985)") struct RecipeDetailViewModelPepTalkTests {

    @Test func shouldShowPepTalkIsTrueWhenJournalIsEmpty() async {
        let viewModel = Self.makeViewModel(totalCookCount: 0)
        #expect(await viewModel.shouldShowPepTalk() == true)
    }

    @Test func shouldShowPepTalkIsFalseAfterOneCook() async {
        let viewModel = Self.makeViewModel(totalCookCount: 1)
        #expect(await viewModel.shouldShowPepTalk() == false)
    }

    @Test func shouldShowPepTalkIsFalseAfterManyCooks() async {
        let viewModel = Self.makeViewModel(totalCookCount: 5)
        #expect(await viewModel.shouldShowPepTalk() == false)
    }

    @Test func pepTalkStateStartsFalse() {
        let viewModel = Self.makeViewModel(totalCookCount: 0)
        #expect(viewModel.isPepTalkPresented == false)
        #expect(viewModel.pepTalkStartRequested == false)
    }

    private static func makeViewModel(totalCookCount: Int) -> RecipeDetailViewModel {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.totalCookCount = totalCookCount
        return RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: 985),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/985/")
                ?? URL(filePath: "/"),
            dependencies: dependencies
        )
    }
}
