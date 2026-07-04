import DODAnalytics
import DODDomain
import DODFeatureProfile
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
    /// T-732 / CL-129: lets blurb-extraction tests drive
    /// ``ArticleBodyExtractor/extractRecipeBlurb(html:)`` through the
    /// real production path. Default is the legacy `"<html></html>"`
    /// shape that pre-T-732 tests relied on (empty extract → empty
    /// `blurbBlocks` → backward-compatible).
    var htmlToReturn: String = "<html></html>"
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

    // MARK: - Article-classification test surface (US-37 / CL-63 / T-640)

    /// Canned article body returned by `extractArticleBody(html:)`. Empty by
    /// default — tests that exercise the article-classification branch set
    /// this to a non-empty string to drive the view model into `.article`
    /// state; tests that want the terminal `.unavailable` fallback leave
    /// it empty (the legacy behavior).
    var articleBodyToExtract: String = ""

    /// DUT-544: canned recipe-SUBJECT signal returned by
    /// `hasRecipeJSONLD(html:)`. Decoupled from `htmlToReturn` because the
    /// fake's HTML is synthetic — tests set this to model a genuine recipe
    /// page (`true`, a `@type: Recipe` node present) vs. a round-up ARTICLE
    /// that merely embeds a WPRM card (`false`, Article/ItemList JSON-LD).
    /// Defaults to `true` so a successfully-parsed `parsedRecipe` (which in
    /// production implies a Recipe node existed) keeps the recipe path.
    var hasRecipeJSONLDResult = true

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
    /// US-44 / CL-139 / DUT-36 Phase d — spy capture of the (name, email)
    /// pair the comment-submit path handed to ``postComment(...)``. Lets
    /// the L1 tests assert the WP REST payload's `author_name` +
    /// `author_email` are sourced from the profile, not from a retired
    /// on-form field.
    var lastPostCommentNameEmail: (name: String, email: String)?
    /// US-44 / CL-139 — same spy for ``postRating(...)`` so the rating-
    /// only path is covered too.
    var lastPostRatingNameEmail: (name: String, email: String)?
    /// When non-nil, `postComment` throws this specific error (takes
    /// precedence over `postCommentShouldFail`). Lets DUT-7 tests inject a
    /// typed `WPClientError` (e.g. `.httpStatusWithBody`) to assert the
    /// view-model surfaces the right category-specific snackbar.
    var postCommentError: Error?
    var guestIdentity: (name: String, email: String)?
    var saveGuestIdentityShouldFail = false

    /// US-44 / CL-138 / DUT-36 Phase c — canned profile returned by
    /// ``loadUserProfile()``. `nil` (the default) keeps the
    /// pre-Phase-c tests honest — the Ratings & Reviews gate fires
    /// because no profile is set up. Tests that exercise the
    /// "ungated" branch set this to a populated ``UserProfile``.
    var profileToLoad: UserProfile?
    /// Spy counter so the view-model tests can prove
    /// ``RecipeDetailViewModel/refreshProfile()`` actually routed
    /// through the dependency surface (initial load + sheet dismiss).
    var loadUserProfileCallCount = 0

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
        return htmlToReturn
    }

    func parseJSONLD(html: String, merging: RecipeListItem, canonicalURL: URL) throws -> Recipe {
        if fetchShouldFail { throw URLError(.cannotParseResponse) }
        guard let parsed = parsedRecipe else { throw URLError(.badServerResponse) }
        return parsed
    }

    /// US-37 / CL-63 / T-640: return the canned `articleBodyToExtract`
    /// regardless of `html`. The view model only inspects the return
    /// value's emptiness to decide between `.article` and the terminal
    /// `.unavailable` path; tests configure `articleBodyToExtract` to
    /// drive the desired branch.
    func extractArticleBody(html: String) -> String {
        articleBodyToExtract
    }

    /// DUT-544: return the canned recipe-subject signal, independent of `html`.
    func hasRecipeJSONLD(html: String) -> Bool {
        hasRecipeJSONLDResult
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
        // T-761 / CL-158 (DUT-67) — downloading also SAVES (idempotent on
        // the save side). Mirrors `LiveRecipeDetailDependencies`.
        savedIDs.insert(recipe.id)
        // Only a real prior download counts as already-downloaded now; a
        // merely-*saved* recipe downloads fresh (save/download decoupled).
        if downloadedIDs.contains(recipe.id) {
            return .alreadyDownloaded
        }
        downloadedIDs.insert(recipe.id)
        return .firstTime
    }

    func removeDownload(id: Int) async throws {
        downloadedIDs.remove(id)
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
        lastPostRatingNameEmail = (name, email)
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

    /// DUT-387 — records held-comment writes routed to the pending bucket.
    var cachedPendingCommentWrites: [(comment: RecipeComment, postID: Int)] = []

    func cachePendingComment(_ comment: RecipeComment, postID: Int) async {
        cachedPendingCommentWrites.append((comment, postID))
    }

    func postComment(
        postID: Int,
        body: String,
        name: String,
        email: String,
        rating: Int?
    ) async throws -> RecipeComment {
        lastPostCommentNameEmail = (name, email)
        if let postCommentError { throw postCommentError }
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

    func loadUserProfile() async -> UserProfile? {
        loadUserProfileCallCount += 1
        return profileToLoad
    }

    // MARK: - Add to Shopping List (DUT-534)

    /// Canned result for ``addToShoppingList(_:)``. Defaults to `.couldntLoad`
    /// (matches the protocol default) so tests that don't exercise the append
    /// keep passing; the DUT-534 test sets a `.added` result.
    var addToShoppingListResult: AddToShoppingListResult = .couldntLoad
    /// Recipes the fake was asked to append, so a test can assert the exact
    /// (already-loaded) recipe was routed through the seam.
    private(set) var addToShoppingListRecipes: [Recipe] = []

    func addToShoppingList(_ recipe: Recipe) async -> AddToShoppingListResult {
        addToShoppingListRecipes.append(recipe)
        return addToShoppingListResult
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
        ingredients: [RecipeIngredient]? = nil,
        kind: PostKind = .recipe
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
            servings: servings,
            kind: kind
        )
    }
}
