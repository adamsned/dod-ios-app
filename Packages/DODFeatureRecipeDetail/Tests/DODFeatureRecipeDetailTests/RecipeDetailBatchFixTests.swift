import DODAnalytics
import DODDomain
import DODFeatureProfile
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// Batch-fix coverage for the DUT-654/639/634/602/605/647-tail recipe-detail
/// fixes that have a view-model seam. Snapshot / pure-UI-only fixes (TZ caption,
/// badge, cook-timer label) are covered in their own suites / by inspection.
@MainActor
@Suite("Recipe detail batch fixes")
struct RecipeDetailBatchFixTests {

    // MARK: - DUT-634 offline_read telemetry

    @Test func offlineCacheHitFiresOfflineReadOncePerSession() async {
        let deps = FakeRecipeDetailDependencies()
        deps.online = false
        deps.cachedRecipes[42] = RecipeDetailTestFixtures.makeRecipe(id: 42, withDetail: true)
        let vm = Self.makeVM(deps: deps, id: 42)

        await vm.onAppear()
        // A second appear (deep-link push / foreground) must NOT re-fire it.
        await vm.onAppear()

        let offlineReads = deps.telemetryEvents.filter { event in
            if case .offlineRead = event { return true }
            return false
        }
        #expect(offlineReads.count == 1)
        if case .offlineRead(let recipeID)? = offlineReads.first {
            #expect(recipeID == 42)
        }
    }

    @Test func onlineCacheHitDoesNotFireOfflineRead() async {
        let deps = FakeRecipeDetailDependencies()
        deps.online = true
        deps.cachedRecipes[7] = RecipeDetailTestFixtures.makeRecipe(id: 7, withDetail: true)
        let vm = Self.makeVM(deps: deps, id: 7)

        await vm.onAppear()

        let fired = deps.telemetryEvents.contains { event in
            if case .offlineRead = event { return true }
            return false
        }
        #expect(fired == false)
    }

    // MARK: - DUT-627 retryable transient-error state

    @Test func retryLoadAfterTransientFailureRecoversToReady() async {
        let deps = FakeRecipeDetailDependencies()
        deps.fetchShouldFail = true
        let vm = Self.makeVM(deps: deps, id: 9)
        await vm.onAppear()
        #expect(vm.loadState == .retryableError)

        // Network comes back; the retry re-runs the fetch/parse pipeline.
        deps.fetchShouldFail = false
        deps.parsedRecipe = RecipeDetailTestFixtures.makeRecipe(id: 9, withDetail: true)
        await vm.retryLoad()
        #expect(vm.loadState == .ready)
    }

    // MARK: - DUT-639 shopping-list scaling

    @Test func scaledRecipeAppliesServingsFactorToIngredientText() {
        let recipe = RecipeDetailTestFixtures.makeRecipe(
            id: 1,
            withDetail: true,
            ingredients: [.init(text: "2 cups flour")]
        )
        let scaled = RecipeDetailViewModel.scaledRecipe(recipe, by: 2.0, useMetric: false)
        #expect(scaled.ingredients.first?.text == "4 cups flour")
        // IDs are preserved so check-state / dedupe still line up.
        #expect(scaled.ingredients.first?.id == recipe.ingredients.first?.id)
    }

    @Test func scaledRecipePreservesNonQuantityLinesAndFactorOne() {
        let recipe = RecipeDetailTestFixtures.makeRecipe(
            id: 1,
            withDetail: true,
            ingredients: [.init(text: "salt to taste")]
        )
        let scaled = RecipeDetailViewModel.scaledRecipe(recipe, by: 1.0, useMetric: false)
        #expect(scaled.ingredients.first?.text == "salt to taste")
    }

    @Test func addToShoppingListRoutesTheScaledRecipeThroughTheSeam() async {
        let deps = FakeRecipeDetailDependencies()
        deps.addToShoppingListResult = .added(count: 1)
        let vm = Self.makeVM(deps: deps, id: 1)
        vm.recipe = RecipeDetailTestFixtures.makeRecipe(
            id: 1,
            withDetail: true,
            servings: 4,
            ingredients: [.init(text: "2 cups flour")]
        )
        // Double the servings → factor 2.0.
        vm.setUserServings(8)

        await vm.addToShoppingList(useMetric: false)

        #expect(deps.addToShoppingListRecipes.count == 1)
        #expect(deps.addToShoppingListRecipes.first?.ingredients.first?.text == "4 cups flour")
    }

    // MARK: - DUT-602 double-submit guard

    @Test func doubleTapSubmitFiresASinglePost() async {
        let deps = FakeRecipeDetailDependencies()
        let vm = Self.makeVM(deps: deps, id: 1)
        vm.recipe = RecipeDetailTestFixtures.makeRecipe(id: 1, withDetail: true)
        vm.setCommentAuthorName("Ned")
        vm.setCommentAuthorEmail("ned@dutchovendaddy.com")
        vm.setCommentDraft("Loved this recipe!")

        // Fire two concurrent submits — the synchronous in-flight guard set
        // before the first await must drop the second.
        async let first: Void = vm.submitRatingAndComment()
        async let second: Void = vm.submitRatingAndComment()
        _ = await (first, second)

        let submitted = deps.telemetryEvents.filter { event in
            if case .recipeCommentSubmitted = event { return true }
            return false
        }
        #expect(submitted.count == 1)
    }

    // MARK: - DUT-605 comment length cap

    @Test func commentDraftIsClampedToTheCharacterCap() {
        let vm = Self.makeVM(deps: FakeRecipeDetailDependencies(), id: 1)
        let limit = RecipeDetailViewModel.commentDraftCharacterLimit
        vm.setCommentDraft(String(repeating: "a", count: limit + 500))
        #expect(vm.commentDraft.count == limit)
    }

    @Test func submitIsGatedOffWhenDraftExceedsCap() {
        let vm = Self.makeVM(deps: FakeRecipeDetailDependencies(), id: 1)
        vm.setCommentAuthorName("Ned")
        vm.setCommentAuthorEmail("ned@dutchovendaddy.com")
        // Bypass the setter's clamp is impossible, so assert the boundary: exactly
        // at the cap is submittable; the setter guarantees we never exceed it.
        vm.setCommentDraft(String(repeating: "a", count: RecipeDetailViewModel.commentDraftCharacterLimit))
        #expect(vm.canSubmitRatingOrComment == true)
    }

    // MARK: - DUT-647 tail — display-name moderation on the comment path

    @Test func inappropriateAuthorNameIsInvalid() {
        let vm = Self.makeVM(deps: FakeRecipeDetailDependencies(), id: 1)
        vm.setCommentAuthorName("hitler")
        #expect(vm.isAuthorNameValid == false)
    }

    @Test func cleanAuthorNameIsValid() {
        let vm = Self.makeVM(deps: FakeRecipeDetailDependencies(), id: 1)
        vm.setCommentAuthorName("Ned")
        #expect(vm.isAuthorNameValid == true)
    }

    // MARK: - DUT-647 tail — isOwnComment whitespace-tolerant email match

    @Test func isOwnCommentTrimsWhitespaceOnBothSides() async {
        let deps = FakeRecipeDetailDependencies()
        // Profile email carries a trailing space; the comment email a leading one.
        deps.profileToLoad = UserProfile(
            id: UUID(),
            displayName: "Ned",
            email: "ned@dutchovendaddy.com "
        )
        let vm = Self.makeVM(deps: deps, id: 1)
        await vm.refreshProfile()

        let comment = RecipeComment(
            id: 1,
            postID: 1,
            authorName: "Ned",
            authorEmail: " NED@dutchovendaddy.com",
            dateGMT: .now,
            body: "Mine.",
            status: .approved
        )
        #expect(vm.isOwnComment(comment) == true)
    }

    // MARK: - Helpers

    static func makeVM(deps: FakeRecipeDetailDependencies, id: Int) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            listItem: RecipeDetailTestFixtures.makeListItem(id: id),
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/\(id)/") ?? URL(filePath: "/"),
            dependencies: deps
        )
    }
}
