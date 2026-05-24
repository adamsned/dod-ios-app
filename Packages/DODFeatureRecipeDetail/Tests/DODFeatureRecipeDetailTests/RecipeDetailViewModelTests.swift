import DODAnalytics
import DODDomain
import DODNetworking
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

    @Test func cookModeTelemetryFiresOnceThenIsIdempotent() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = Self.makeRecipe(id: 11, withDetail: true)
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 11)
        await viewModel.onAppear()
        await viewModel.didTapCookMode()
        await viewModel.didTapCookMode()
        await viewModel.didTapCookMode()
        // AC-7.7 — "first time Cook Mode is entered for a given recipe
        // during a session" — repeat taps don't re-fire.
        let cookEvents = dependencies.telemetryEvents.filter { event in
            if case .cookModeStarted = event { return true }
            return false
        }
        #expect(cookEvents.count == 1)
        if case .cookModeStarted(let recipeID) = cookEvents.first {
            #expect(recipeID == 11)
        } else {
            Issue.record("Expected cookModeStarted event")
        }
    }

    @Test func mergeIngredientChecksReplacesSet() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = Self.makeRecipe(id: 12, withDetail: true)
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 12)
        await viewModel.onAppear()
        let id1 = UUID()
        let id2 = UUID()
        viewModel.mergeIngredientChecks([id1, id2])
        #expect(viewModel.checkedIngredientIDs == [id1, id2])
        viewModel.mergeIngredientChecks([])
        #expect(viewModel.checkedIngredientIDs.isEmpty)
    }

    // MARK: - US-13/14/15 — comments + ratings integration

    @Test func onAppearLoadsRatingSummaryAndCommentsFromNetwork() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = Self.makeRecipe(id: 50, withDetail: true)
        dependencies.fetchedRatingSummary = RecipeRating(recipeID: 50, average: 4.2, count: 17)
        dependencies.fetchedComments = [Self.makeComment(id: 1, postID: 50, body: "Loved it.")]
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 50)

        await viewModel.onAppear()

        #expect(viewModel.ratingSummary?.average == 4.2)
        #expect(viewModel.ratingSummary?.count == 17)
        #expect(viewModel.comments.count == 1)
        #expect(viewModel.commentsLoadState == .ready)
        // Cache write should have happened so a relaunch sees the latest.
        #expect(!dependencies.cachedRatingWrites.isEmpty)
        #expect(!dependencies.cachedCommentWrites.isEmpty)
    }

    @Test func loadRatingsAndCommentsKeepsCacheWhenNetworkFails() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = Self.makeRecipe(id: 51, withDetail: true)
        dependencies.cachedCommentsByPost[51] = [
            Self.makeComment(id: 99, postID: 51, body: "Cached comment.")
        ]
        dependencies.commentsFetchShouldFail = true
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 51)

        await viewModel.onAppear()

        // AC-14.6: with a populated cache, a network failure must NOT
        // collapse to an error state — the user keeps seeing what they
        // had before.
        #expect(viewModel.comments.count == 1)
        #expect(viewModel.commentsLoadState == .ready)
    }

    @Test func loadRatingsAndCommentsErrorsWhenCacheAndNetworkAreEmpty() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = Self.makeRecipe(id: 52, withDetail: true)
        dependencies.commentsFetchShouldFail = true
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 52)

        await viewModel.onAppear()

        if case .error = viewModel.commentsLoadState {
            // Expected.
        } else {
            Issue.record("Expected .error state when both cache and network are empty")
        }
    }

    @Test func submitRatingSendsTelemetryAndUpdatesSummary() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = Self.makeRecipe(id: 60, withDetail: true)
        dependencies.guestIdentity = (name: "Jamie", email: "jamie@example.com")
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 60)
        await viewModel.onAppear()

        await viewModel.submitRating(stars: 4)

        #expect(viewModel.ratingSummary?.userRating == 4)
        #expect(viewModel.pendingUserRating == 4)
        #expect(viewModel.snackbarMessage != nil)
        let ratedEvents = dependencies.telemetryEvents.filter { event in
            if case .recipeRated = event { return true }
            return false
        }
        #expect(ratedEvents.count == 1)
    }

    @Test func submitRatingWithoutIdentitySetsGate() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = Self.makeRecipe(id: 61, withDetail: true)
        // No identity preloaded — submit must not POST.
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 61)
        await viewModel.onAppear()

        await viewModel.submitRating(stars: 3)

        #expect(viewModel.requiresGuestIdentity == true)
        let ratedEvents = dependencies.telemetryEvents.filter { event in
            if case .recipeRated = event { return true }
            return false
        }
        #expect(ratedEvents.isEmpty, "Rating must not POST without an identity")
    }

    @Test func submitCommentPrependsApprovedAndSnackbars() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = Self.makeRecipe(id: 70, withDetail: true)
        dependencies.guestIdentity = (name: "Sam", email: "sam@example.com")
        dependencies.postedCommentResult = Self.makeComment(
            id: 999, postID: 70, body: "Approved comment.", status: .approved
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 70)
        await viewModel.onAppear()

        viewModel.setCommentDraft("Approved comment.")
        await viewModel.submitComment()

        #expect(viewModel.comments.first?.id == 999)
        #expect(viewModel.commentDraft.isEmpty)
        #expect(viewModel.snackbarMessage == "Comment posted.")
        let submitted = dependencies.telemetryEvents.compactMap { event -> Bool? in
            if case .recipeCommentSubmitted(_, let awaiting) = event { return awaiting }
            return nil
        }
        #expect(submitted == [false])
    }

    @Test func submitCommentMarksHeldAsAwaitingApproval() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = Self.makeRecipe(id: 71, withDetail: true)
        dependencies.guestIdentity = (name: "Sam", email: "sam@example.com")
        dependencies.postedCommentResult = Self.makeComment(
            id: 1000, postID: 71, body: "Held comment.", status: .hold
        )
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 71)
        await viewModel.onAppear()

        viewModel.setCommentDraft("Held comment.")
        await viewModel.submitComment()

        // AC-14.4: held comments must NOT be prepended.
        #expect(viewModel.comments.contains { $0.id == 1000 } == false)
        #expect(viewModel.snackbarMessage == "Submitted for moderation.")
        let submitted = dependencies.telemetryEvents.compactMap { event -> Bool? in
            if case .recipeCommentSubmitted(_, let awaiting) = event { return awaiting }
            return nil
        }
        #expect(submitted == [true])
    }

    @Test func saveGuestIdentityClearsTheGate() async throws {
        let dependencies = FakeRecipeDetailDependencies()
        dependencies.parsedRecipe = Self.makeRecipe(id: 80, withDetail: true)
        let viewModel = Self.makeViewModel(dependencies: dependencies, listItemID: 80)
        await viewModel.onAppear()
        #expect(viewModel.requiresGuestIdentity == true)

        await viewModel.saveGuestIdentityAndContinue(name: "Alex", email: "alex@example.com")

        #expect(viewModel.requiresGuestIdentity == false)
        #expect(dependencies.savedGuestIdentities.count == 1)
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

    static func makeComment(
        id: Int,
        postID: Int,
        body: String,
        status: RecipeComment.Status = .approved
    ) -> RecipeComment {
        RecipeComment(
            id: id,
            postID: postID,
            parentID: nil,
            authorName: "Reviewer \(id)",
            avatarURL: nil,
            dateGMT: Date(timeIntervalSince1970: 1_700_000_000),
            body: body,
            ratingValue: nil,
            status: status
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

    // MARK: - Comments + ratings test surface

    /// Pre-loaded rating summary returned from the network. Defaults to a
    /// zero-rating so tests that don't care about the summary keep
    /// passing the way they did before Wave-2.
    var fetchedRatingSummary: RecipeRating?
    /// Pre-loaded cached rating used by `cachedRatingSummary`. Distinct
    /// from `fetchedRatingSummary` so tests can model "cache hit, network
    /// stale" and "cache miss" independently.
    var cachedRatingByRecipe: [Int: RecipeRating] = [:]
    var cachedCommentsByPost: [Int: [RecipeComment]] = [:]
    var fetchedComments: [RecipeComment] = []
    var fetchedCommentsTotalPages: Int = 1
    var fetchedCommentsTotalCount: Int = 0
    var commentsFetchShouldFail = false
    var postedRatingResult: RecipeRating?
    var postRatingShouldFail = false
    var postedCommentResult: RecipeComment?
    var postCommentShouldFail = false
    var guestIdentity: (name: String, email: String)?
    var saveGuestIdentityShouldFail = false

    // Spy state for tests that care about call order / persistence.
    var cachedRatingWrites: [RecipeRating] = []
    var cachedCommentWrites: [(comments: [RecipeComment], postID: Int)] = []
    var savedGuestIdentities: [(name: String, email: String)] = []

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

    func fetchRatingSummary(recipeID: Int) async -> RecipeRating {
        fetchedRatingSummary
            ?? RecipeRating(recipeID: recipeID, average: 0, count: 0, userRating: nil)
    }

    func cachedRatingSummary(recipeID: Int) async -> RecipeRating? {
        cachedRatingByRecipe[recipeID]
    }

    func cacheRatingSummary(_ summary: RecipeRating) async {
        cachedRatingWrites.append(summary)
        cachedRatingByRecipe[summary.recipeID] = summary
    }

    func postRating(
        recipeID: Int,
        stars: Int,
        name: String,
        email: String
    ) async throws -> RecipeRating {
        if postRatingShouldFail { throw URLError(.badServerResponse) }
        let result =
            postedRatingResult
            ?? RecipeRating(recipeID: recipeID, average: Double(stars), count: 1, userRating: stars)
        // Mirror production: telemetry only fires on success.
        await sendTelemetry(.recipeRated(recipeID: recipeID, stars: stars))
        return result
    }

    func fetchComments(
        postID: Int,
        page: Int
    ) async throws -> WPCommentsClient.CommentsPage {
        if commentsFetchShouldFail { throw URLError(.notConnectedToInternet) }
        return WPCommentsClient.CommentsPage(
            comments: fetchedComments,
            totalPages: fetchedCommentsTotalPages,
            totalCount: fetchedCommentsTotalCount
        )
    }

    func cachedComments(postID: Int) async -> [RecipeComment] {
        cachedCommentsByPost[postID] ?? []
    }

    func cacheComments(_ comments: [RecipeComment], postID: Int) async {
        cachedCommentWrites.append((comments, postID))
        cachedCommentsByPost[postID] = comments
    }

    func postComment(
        postID: Int,
        body: String,
        name: String,
        email: String,
        rating: Int?
    ) async throws -> RecipeComment {
        if postCommentShouldFail { throw URLError(.badServerResponse) }
        let result =
            postedCommentResult
            ?? RecipeComment(
                id: Int.random(in: 1_000_000...9_999_999),
                postID: postID,
                authorName: name,
                avatarURL: nil,
                dateGMT: .now,
                body: body,
                ratingValue: rating,
                status: .approved
            )
        await sendTelemetry(
            .recipeCommentSubmitted(
                recipeID: postID,
                awaitingApproval: result.status != .approved
            )
        )
        return result
    }

    func loadGuestIdentity() async -> (name: String, email: String)? {
        guestIdentity
    }

    func saveGuestIdentity(name: String, email: String) async throws {
        if saveGuestIdentityShouldFail {
            throw URLError(.cannotWriteToFile)
        }
        savedGuestIdentities.append((name, email))
        guestIdentity = (name, email)
    }
}
