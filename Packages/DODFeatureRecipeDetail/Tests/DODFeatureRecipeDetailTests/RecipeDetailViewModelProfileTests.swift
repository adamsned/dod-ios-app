import DODAnalytics
import DODDomain
import DODFeatureProfile
import DODNetworking
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// L1 — pin the Phase c profile gate contract on
/// ``RecipeDetailViewModel``: `hasProfile` derivation, the
/// ``refreshProfile()`` re-read path, and the `onAppear` initial load.
///
/// Spec trace: US-44 AC-44.10; CL-138; DUT-36 Phase c.
@MainActor
@Suite("RecipeDetailViewModel — profile gate (T-741)") struct RecipeDetailViewModelProfileTests {

    @Test func hasProfileIsFalseWhenStoreReturnsNil() async {
        let dependencies = FakeRecipeDetailDependencies()
        // profileToLoad left nil (the default) — store has nothing.
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 1)
        await viewModel.refreshProfile()
        #expect(viewModel.profile == nil)
        #expect(viewModel.hasProfile == false)
    }

    @Test func hasProfileIsTrueWhenStoreReturnsProfile() async {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.profileToLoad = Self.makeProfile(displayName: "Spencer")
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 2)
        await viewModel.refreshProfile()
        #expect(viewModel.profile?.displayName == "Spencer")
        #expect(viewModel.hasProfile == true)
    }

    @Test func refreshProfilePicksUpStoreMutations() async {
        // Simulates the gate sheet's `.onDisappear` flow: the user
        // creates a profile while the sheet is open, dismisses the
        // sheet, the section calls `refreshProfile()`, and the
        // `@Observable` flip happens.
        let dependencies = FakeRecipeDetailDependencies()
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 3)
        await viewModel.refreshProfile()
        #expect(viewModel.hasProfile == false)

        // Now the user finishes the modal sheet — the store gains a
        // profile and we re-read.
        dependencies.profileToLoad = Self.makeProfile(displayName: "Ned")
        await viewModel.refreshProfile()

        #expect(viewModel.hasProfile == true)
        #expect(viewModel.profile?.displayName == "Ned")
    }

    @Test func onAppearTriggersInitialProfileLoad() async {
        // The eager load in `onAppear()` is what guarantees the gate is
        // computed before the user can scroll to the Ratings section.
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.profileToLoad = Self.makeProfile(displayName: "Jamie")
        // Provide a parsed recipe so the existing onAppear path doesn't
        // fall through to `.unavailable` and crash the existing
        // ratings + comments load layered below it.
        dependencies.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(
            id: 4,
            withDetail: true,
            categoryID: 336
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 4)

        await viewModel.onAppear()

        #expect(viewModel.hasProfile == true)
        #expect(viewModel.profile?.displayName == "Jamie")
        #expect(
            dependencies.loadUserProfileCallCount >= 1,
            "onAppear must hit `loadUserProfile()` so the gate is computed eagerly"
        )
    }

    @Test func defaultDependencyImplementationReturnsNilProfile() async {
        // Pre-Phase-c fakes (real production code in the same test target
        // that don't override `loadUserProfile()`) must keep returning
        // nil — pinned by the protocol-extension default. This is what
        // keeps the existing test suite honest without touching every
        // fake to opt in.
        struct MinimalFake: RecipeDetailDependencies, @unchecked Sendable {
            // The protocol surface is wide; tests typically use
            // `FakeRecipeDetailDependencies`. Here we only need to
            // assert the default impl. The other methods are
            // unreachable in this test.
            func cachedRecipe(id: Int) async throws -> Recipe? { nil }
            func fetchHTML(for url: URL) async throws -> String { "" }
            func parseJSONLD(html: String, merging: RecipeListItem, canonicalURL: URL) throws -> Recipe { throw URLError(.unknown) }
            func relatedRecipes(forCategoryID: Int) async throws -> [RecipeListItem] { [] }
            func mergeDetail(_ recipe: Recipe) async throws {}
            func markJSONLDFailed(id: Int) async throws {}
            func isSaved(id: Int) async throws -> Bool { false }
            func toggleSaved(id: Int) async throws -> Bool { false }
            func isOnline() async -> Bool { true }
            func sendTelemetry(_ event: AnalyticsEvent) async {}
            func isDownloaded(id: Int) async throws -> Bool { false }
            func downloadForOffline(recipe: Recipe) async throws -> DownloadOutcome { .firstTime }
            func fetchRatingSummary(recipeID: Int) async -> RecipeRating {
                RecipeRating(recipeID: recipeID, average: 0, count: 0, userRating: nil)
            }
            func cachedRatingSummary(recipeID: Int) async -> RecipeRating? { nil }
            func cacheRatingSummary(_ summary: RecipeRating) async {}
            func postRating(recipeID: Int, stars: Int, name: String, email: String) async throws -> RecipeRating {
                throw URLError(.unknown)
            }
            func fetchComments(postID: Int, page: Int) async throws -> WPCommentsClient.CommentsPage {
                throw URLError(.unknown)
            }
            func cachedComments(postID: Int) async -> [RecipeComment] { [] }
            func cacheComments(_ comments: [RecipeComment], postID: Int) async {}
            func postComment(postID: Int, body: String, name: String, email: String, rating: Int?) async throws -> RecipeComment {
                throw URLError(.unknown)
            }
            func loadGuestIdentity() async -> (name: String, email: String)? { nil }
            func saveGuestIdentity(name: String, email: String) async throws {}
            // Deliberately NOT overriding `loadUserProfile` — the
            // protocol-extension default applies.
        }

        let fake = MinimalFake()
        let profile = await fake.loadUserProfile()
        #expect(profile == nil)
    }

    // MARK: - Helpers

    private static func makeViewModel(
        dependencies: RecipeDetailDependencies,
        listItemID: Int
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: listItemID),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(listItemID)/") ?? URL(filePath: "/"),
            dependencies: dependencies
        )
    }

    private static func makeProfile(displayName: String) -> UserProfile {
        UserProfile(
            id: UUID(),
            displayName: displayName,
            email: "\(displayName.lowercased())@example.com",
            photoFilename: nil
        )
    }
}
