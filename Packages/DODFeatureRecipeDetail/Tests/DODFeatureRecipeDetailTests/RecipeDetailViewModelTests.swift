import DODAnalytics
import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@MainActor
@Suite("RecipeDetailViewModel (T-110..T-121)") struct RecipeDetailViewModelTests {

    @Test func successfulFetchPopulatesRecipeAndRelated() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = Self.makeRecipe(id: 1, withDetail: true, categoryID: 336)
        dependencies.related = [Self.makeListItem(id: 100), Self.makeListItem(id: 101)]
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 1)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .ready)
        #expect(viewModel.recipe?.ingredients.count == 2)
        #expect(viewModel.related.count == 2)
    }

    @Test func fetchFailureMarksBlocklistAndTransitionsToUnavailable() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.fetchShouldFail = true
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 9)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .unavailable)
        #expect(dependencies.markedFailedIDs == [9])
    }

    @Test func cachedRecipeWithDetailSkipsNetwork() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.cachedRecipes[42] = Self.makeRecipe(id: 42, withDetail: true)
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 42)
        await viewModel.onAppear()
        #expect(viewModel.loadState == .ready)
        #expect(dependencies.fetchCount == 0, "Cache hit must not fetch")
    }

    @Test func toggleSavedSendsTelemetryAndShowsSnackbar() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = Self.makeRecipe(id: 5, withDetail: true)
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 5)
        await viewModel.onAppear()
        await viewModel.toggleSaved()
        #expect(viewModel.isSaved == true)
        #expect(viewModel.snackbarMessage != nil)
        #expect(
            dependencies.telemetryEvents.contains { event in
                if case .recipeSaved = event { return true }
                return false
            }
        )
    }

    @Test func shareSendsTelemetry() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = Self.makeRecipe(id: 5, withDetail: true)
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 5)
        await viewModel.onAppear()
        await viewModel.didShare()
        #expect(
            dependencies.telemetryEvents.contains { event in
                if case .recipeShared = event { return true }
                return false
            }
        )
    }

    @Test func toggleIngredientCheckIsLocalOnly() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = Self.makeRecipe(id: 5, withDetail: true)
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 5)
        await viewModel.onAppear()
        let firstID = try #require(viewModel.recipe?.ingredients.first?.id)
        viewModel.toggleIngredient(firstID)
        #expect(viewModel.checkedIngredientIDs.contains(firstID))
        viewModel.toggleIngredient(firstID)
        #expect(!viewModel.checkedIngredientIDs.contains(firstID))
    }

    // MARK: - Helpers

    static func makeViewModel(
        dependencies: RecipeDetailDependencies,
        listItemID: Int
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: makeListItem(id: listItemID),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(listItemID)/") ?? URL(filePath: "/"),
            dependencies: dependencies
        )
    }

    static func makeListItem(id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Recipe \(id)",
            excerpt: "Tasty.",
            heroImage: nil,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            totalTimeDisplay: nil
        )
    }

    static func makeRecipe(id: Int, withDetail: Bool, categoryID: Int = 0) -> Recipe {
        Recipe(
            id: id,
            slug: "slug-\(id)",
            title: "Recipe \(id)",
            excerpt: "Tasty.",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/") ?? URL(filePath: "/"),
            categoryIDs: categoryID > 0 ? [categoryID] : [],
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: withDetail ? [.init(text: "salt"), .init(text: "pepper")] : [],
            instructions: withDetail ? [.init(step: 1, text: "Stir.")] : [],
            totalTime: .seconds(15 * 60)
        )
    }
}

final class FakeRecipeDetailDependencies: RecipeDetailDependencies, @unchecked Sendable {
    var cachedRecipes: [Int: Recipe] = [:]
    var parsedRecipe: Recipe?
    var related: [RecipeListItem] = []
    var fetchShouldFail = false
    var savedIDs: Set<Int> = []
    var online = true
    var markedFailedIDs: [Int] = []
    var telemetryEvents: [AnalyticsEvent] = []
    var fetchCount = 0

    func cachedRecipe(id: Int) async throws -> Recipe? { cachedRecipes[id] }

    func fetchHTML(for url: URL) async throws -> String {
        fetchCount += 1
        if fetchShouldFail { throw URLError(.notConnectedToInternet) }
        return "<html></html>"
    }

    func parseJSONLD(html: String, merging: RecipeListItem, canonicalURL: URL) throws -> Recipe {
        if fetchShouldFail { throw URLError(.cannotParseResponse) }
        guard let parsed = parsedRecipe else { throw URLError(.badServerResponse) }
        return parsed
    }

    func relatedRecipes(forCategoryID: Int) async throws -> [RecipeListItem] { related }

    func mergeDetail(_ recipe: Recipe) async throws {
        cachedRecipes[recipe.id] = recipe
    }

    func markJSONLDFailed(id: Int) async throws { markedFailedIDs.append(id) }

    func isSaved(id: Int) async throws -> Bool { savedIDs.contains(id) }

    func toggleSaved(id: Int) async throws -> Bool {
        if savedIDs.contains(id) {
            savedIDs.remove(id)
            return false
        } else {
            savedIDs.insert(id)
            return true
        }
    }

    func isOnline() async -> Bool { online }
    func sendTelemetry(_ event: AnalyticsEvent) async { telemetryEvents.append(event) }
}
