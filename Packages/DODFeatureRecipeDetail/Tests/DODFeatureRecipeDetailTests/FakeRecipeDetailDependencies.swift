import DODAnalytics
import DODDomain
import DODNetworking
import Foundation

@testable import DODFeatureRecipeDetail

/// In-memory ``RecipeDetailDependencies`` for the recipe-detail unit tests.
/// Extracted from the original `RecipeDetailViewModelTests.swift` so that
/// (a) the test file stays under the 400-line lint ceiling, and (b) the
/// new regression suites (`RecipeDetailRatingsRenderingTests`,
/// `RecipeDetailRatingsViewSnapshotTests`, etc.) can share the same fake
/// without duplicating its surface.
///
/// The fake is `@unchecked Sendable` because the tests drive it
/// single-threaded from `@MainActor` and the inner mutable state never
/// crosses an actor boundary on its own. Concurrent test usage would
/// require real locking — out of scope for this regression bundle.
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
    /// US-35 spy state: recipe IDs the test has flagged as downloaded
    /// (mirrors `CachedRecipe.downloadedAt != nil`). Production routes
    /// through `RecipeStore.markDownloaded(id:)`.
    var downloadedIDs: Set<Int> = []
    /// Per-recipe download-call counter so AC-35.4's "no second image
    /// fetch on re-tap" idempotency contract can be locked.
    var downloadCallCount: [Int: Int] = [:]
    /// When non-nil, `downloadForOffline(recipe:)` throws this error
    /// before flipping any state — lets tests cover the failure branch
    /// without rigging up `ImageLoader` plumbing.
    var downloadShouldFail = false

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

    // Spy counters introduced for the rendering regression suite — they
    // let those tests assert that `loadRatingsAndComments()` actually
    // routed through the dependency surface, even when the cached recipe
    // path made the fetch skip.
    var fetchRatingSummaryCallCount = 0
    var cachedCommentsCallCount = 0
    var fetchCommentsCallCount = 0

    /// When non-nil, `fetchRatingSummary` awaits this continuation before
    /// returning. Lets a test prove that a hung ratings fetch never
    /// stalls the recipe-detail load state itself.
    var fetchRatingSummaryGate: (@Sendable () async -> Void)?

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

    func isDownloaded(id: Int) async throws -> Bool {
        downloadedIDs.contains(id)
    }

    func downloadForOffline(recipe: Recipe) async throws -> DownloadOutcome {
        if downloadShouldFail { throw URLError(.notConnectedToInternet) }
        downloadCallCount[recipe.id, default: 0] += 1
        // Idempotent in either pin direction (explicit download OR
        // saved-via-AC-5.2). Mirrors `LiveRecipeDetailDependencies`.
        if downloadedIDs.contains(recipe.id) || savedIDs.contains(recipe.id) {
            downloadedIDs.insert(recipe.id)
            return .alreadyDownloaded
        }
        downloadedIDs.insert(recipe.id)
        return .firstTime
    }

    func fetchRatingSummary(recipeID: Int) async -> RecipeRating {
        fetchRatingSummaryCallCount += 1
        if let gate = fetchRatingSummaryGate {
            await gate()
        }
        return fetchedRatingSummary
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
        fetchCommentsCallCount += 1
        if commentsFetchShouldFail { throw URLError(.notConnectedToInternet) }
        return WPCommentsClient.CommentsPage(
            comments: fetchedComments,
            totalPages: fetchedCommentsTotalPages,
            totalCount: fetchedCommentsTotalCount
        )
    }

    func cachedComments(postID: Int) async -> [RecipeComment] {
        cachedCommentsCallCount += 1
        return cachedCommentsByPost[postID] ?? []
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

/// Tiny fixture helpers shared across the recipe-detail test suites —
/// originally inline on `RecipeDetailViewModelTests`, now lifted into a
/// neutral home so the new regression suites can use them too.
enum RecipeDetailTestFixtures {

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

    static func makeRecipe(
        id: Int,
        withDetail: Bool,
        categoryID: Int = 0,
        servings: Int? = nil,
        ingredients: [RecipeIngredient]? = nil
    ) -> Recipe {
        let resolvedIngredients: [RecipeIngredient] =
            ingredients ?? (withDetail ? [.init(text: "salt"), .init(text: "pepper")] : [])
        return Recipe(
            id: id,
            slug: "slug-\(id)",
            title: "Recipe \(id)",
            excerpt: "Tasty.",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/r/\(id)/") ?? URL(filePath: "/"),
            categoryIDs: categoryID > 0 ? [categoryID] : [],
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingredients: resolvedIngredients,
            instructions: withDetail ? [.init(step: 1, text: "Stir.")] : [],
            totalTime: .seconds(15 * 60),
            servings: servings
        )
    }
}
