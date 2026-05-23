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

    func savedRecipes() async throws -> [Recipe] {
        if shouldFail { throw URLError(.unknown) }
        return recipes
    }

    func preDownloadImages(forRecipeID recipeID: Int, urls: [URL]) async {
        preDownloadedRecipeIDs.append(recipeID)
    }
}
