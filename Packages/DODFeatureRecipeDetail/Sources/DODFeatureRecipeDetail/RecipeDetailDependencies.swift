import DODAnalytics
import DODDomain
import DODFeatureProfile
import DODNetworking
import DODPersistence
import DODSupport
import Foundation

/// Surface needed by recipe detail. Production wires to the hybrid REST +
/// JSON-LD fetch path, the WP comments / WPRM ratings clients, and the
/// Keychain-backed guest identity. Tests pass a fake.
///
/// Spec trace: US-13/14/15 (CL-21 amendment) — the new comments + ratings
/// + guest-identity surface, plus the original AC-4.* recipe detail
/// methods.
public protocol RecipeDetailDependencies: Sendable {
    func cachedRecipe(id: Int) async throws -> Recipe?
    func fetchHTML(for url: URL) async throws -> String
    func parseJSONLD(html: String, merging: RecipeListItem, canonicalURL: URL) throws -> Recipe
    /// US-37 / CL-63 / AC-37.2 (T-640) + DOD-ART-1: extract the article body
    /// **HTML** from the rendered page. Called by the view model when
    /// `parseJSONLD(...)` throws — non-empty result classifies the post
    /// as an article (`.article` load state + `ArticleDetailView` render);
    /// empty result falls through to the terminal `.unavailable` path.
    /// Default routes to
    /// ``DODSupport/ArticleBodyExtractor/extractContentHTML(html:)`` (parsed
    /// to native blocks by ``DODSupport/ArticleHTMLParser``); tests pass a fake.
    func extractArticleBody(html: String) -> String
    func relatedRecipes(forCategoryID: Int) async throws -> [RecipeListItem]
    func mergeDetail(_ recipe: Recipe) async throws
    func markJSONLDFailed(id: Int) async throws
    func isSaved(id: Int) async throws -> Bool
    func toggleSaved(id: Int) async throws -> Bool
    func isOnline() async -> Bool
    func sendTelemetry(_ event: AnalyticsEvent) async

    /// Re-publish the saved-recipes widget snapshot. Called by the view
    /// model immediately after every `toggleSaved(id:)` so the home-screen
    /// widget timeline refreshes the same render frame the user sees the
    /// snackbar (US-17 / AC-17.3 + AC-17.6, T-322 host-side glue).
    /// Default no-op so existing fakes keep compiling — only
    /// ``LiveRecipeDetailDependencies`` actually publishes.
    func publishSavedWidgetSnapshot() async

    // MARK: - Explicit download (US-35)
    //
    // The protocol methods + the ``DownloadOutcome`` enum + the live
    // implementation live in `RecipeDetailDependencies+Download.swift`
    // (extension on this protocol + on `LiveRecipeDetailDependencies`).
    // Required surface: `isDownloaded(id:) async throws -> Bool` +
    // `downloadForOffline(recipe:) async throws -> DownloadOutcome`.

    func isDownloaded(id: Int) async throws -> Bool
    func downloadForOffline(recipe: Recipe) async throws -> DownloadOutcome

    // MARK: - Comments + ratings (US-13/14/15)

    /// Fetch the public WPRM rating summary. Never throws — degrades to a
    /// zero-valued ``RecipeRating`` on any failure per REG-14.
    func fetchRatingSummary(recipeID: Int) async -> RecipeRating

    /// Read back the cached aggregate rating for one recipe. `nil` if the
    /// recipe has never been opened (no row yet).
    func cachedRatingSummary(recipeID: Int) async -> RecipeRating?

    /// Persist a fresh aggregate-rating snapshot. Best-effort: errors are
    /// swallowed and logged at the call site — the rating UI never blocks
    /// on disk I/O.
    func cacheRatingSummary(_ summary: RecipeRating) async

    /// POST a star rating to WPRM. Returns the refreshed summary (the
    /// underlying client refetches on success so callers can render the
    /// new average without a separate round-trip). Sends the
    /// ``AnalyticsEvent/recipeRated(recipeID:stars:)`` event on success.
    func postRating(
        recipeID: Int,
        stars: Int,
        name: String,
        email: String
    ) async throws -> RecipeRating

    /// One page of comments newest-first. Surfaces pagination counts via
    /// the underlying ``WPCommentsClient/CommentsPage``.
    func fetchComments(postID: Int, page: Int) async throws -> WPCommentsClient.CommentsPage

    /// Read back the cached comments for one recipe post. Returns pending
    /// (this-device) rows after the approved set — see
    /// ``RecipeStore.cachedComments(forPostID:)``.
    func cachedComments(postID: Int) async -> [RecipeComment]

    /// Persist a fresh page of comments. Errors are swallowed and logged
    /// at the call site.
    func cacheComments(_ comments: [RecipeComment], postID: Int) async

    /// POST a new comment. Returns the comment WP echoed back — the view
    /// model branches on `status` to decide between "Posted" and
    /// "Awaiting approval" copy. Sends the
    /// ``AnalyticsEvent/recipeCommentSubmitted(recipeID:awaitingApproval:)``
    /// event on success.
    func postComment(
        postID: Int,
        body: String,
        name: String,
        email: String,
        rating: Int?
    ) async throws -> RecipeComment

    /// Read the cached guest identity from the Keychain. `nil` if either
    /// the display name or email is missing.
    func loadGuestIdentity() async -> (name: String, email: String)?

    /// Persist a new guest identity to the Keychain. Throws on
    /// `SecItemAdd` / `SecItemDelete` failure so the UI can surface a
    /// "couldn't save" error.
    func saveGuestIdentity(name: String, email: String) async throws

    // MARK: - User profile (US-44 / DUT-36 Phase c)

    /// Read the on-device ``UserProfile`` if one has been saved (the
    /// Phase a Settings → Profile flow), else `nil`. Backs the Ratings
    /// & Reviews write-surface gate in ``RecipeDetailRatingsSection``
    /// via the ``RecipeDetailViewModel/hasProfile`` derivation. Default
    /// returns `nil` so existing fakes don't have to opt in — production
    /// wires through ``LiveRecipeDetailDependencies``. Spec trace:
    /// US-44 AC-44.10; CL-138.
    func loadUserProfile() async -> UserProfile?
}

extension RecipeDetailDependencies {
    /// Default no-op so existing fakes (e.g. `FakeRecipeDetailDependencies`
    /// in the test suite) don't have to opt in to widget publishing. The
    /// live wiring overrides this — see ``LiveRecipeDetailDependencies``.
    public func publishSavedWidgetSnapshot() async {}

    /// US-44 / CL-138 / DUT-36 Phase c — default returns `nil` so any
    /// pre-Phase-c test fake (which doesn't care about profile gating)
    /// keeps compiling AND keeps reporting the "no profile" branch
    /// that the Phase a/b shipped contract assumes by default. Tests
    /// that exercise the gated/ungated split override this to return a
    /// canned ``UserProfile``. Production wires through
    /// ``LiveRecipeDetailDependencies``.
    public func loadUserProfile() async -> UserProfile? { nil }

    /// US-37 / CL-63 / AC-37.2 (T-640) + DOD-ART-1: default routes to
    /// ``DODSupport/ArticleBodyExtractor/extractContentHTML(html:)`` so
    /// production callers get the rich-rendering **HTML** body (parsed into
    /// native blocks by ``DODSupport/ArticleHTMLParser`` in
    /// ``ArticleDetailView``). Tests override this to return a canned body
    /// (or empty string to exercise the unavailable fallback).
    public func extractArticleBody(html: String) -> String {
        ArticleBodyExtractor.extractContentHTML(html: html)
    }
}

public struct LiveRecipeDetailDependencies: RecipeDetailDependencies {

    let client: WPRestClient
    let fetcher: RecipePageFetcher
    let store: RecipeStore
    let monitor: NetworkMonitor
    let commentsClient: WPCommentsClient
    let ratingsClient: WPRMRatingsClient
    let guestIdentity: any GuestIdentityStoring
    /// US-44 / CL-138 / DUT-36 Phase c — backs `loadUserProfile()` so
    /// the Ratings & Reviews gate can read the current device profile.
    /// Optional so unit-test wiring that doesn't care about the gate
    /// stays terse; production passes the singleton
    /// ``KeychainProfileStore`` from `AppDependencies`.
    let profileStore: (any ProfileStoring)?
    let imageLoader: ImageLoader
    private let savedWidgetPublisher: SavedRecipesWidgetPublisher?

    public init(
        client: WPRestClient,
        fetcher: RecipePageFetcher,
        store: RecipeStore,
        monitor: NetworkMonitor,
        commentsClient: WPCommentsClient,
        ratingsClient: WPRMRatingsClient,
        guestIdentity: any GuestIdentityStoring,
        profileStore: (any ProfileStoring)? = nil,
        imageLoader: ImageLoader = ImageLoader(),
        savedWidgetPublisher: SavedRecipesWidgetPublisher? = nil
    ) {
        self.client = client
        self.fetcher = fetcher
        self.store = store
        self.monitor = monitor
        self.commentsClient = commentsClient
        self.ratingsClient = ratingsClient
        self.guestIdentity = guestIdentity
        self.profileStore = profileStore
        self.imageLoader = imageLoader
        // Default to a publisher rooted in the same store + the live App
        // Group; callers can pass nil to disable the side effect for
        // unit-test wiring that doesn't care about widgets.
        self.savedWidgetPublisher = savedWidgetPublisher ?? SavedRecipesWidgetPublisher(store: store)
    }

    public func cachedRecipe(id: Int) async throws -> Recipe? {
        try await store.recipe(id: id)
    }

    public func fetchHTML(for url: URL) async throws -> String {
        try await fetcher.html(for: url)
    }

    public func parseJSONLD(html: String, merging: RecipeListItem, canonicalURL: URL) throws -> Recipe {
        try JSONLDRecipeParser.parse(html: html, merging: merging, canonicalURL: canonicalURL)
    }

    public func relatedRecipes(forCategoryID categoryID: Int) async throws -> [RecipeListItem] {
        let items = try await client.posts(categoryID: categoryID, page: 1, perPage: 5)
        return Array(items.prefix(4))
    }

    public func mergeDetail(_ recipe: Recipe) async throws {
        try await store.mergeDetail(recipe)
    }

    public func markJSONLDFailed(id: Int) async throws {
        try await store.markJSONLDFailed(id: id)
    }

    public func isSaved(id: Int) async throws -> Bool {
        try await store.isSaved(id: id)
    }

    public func toggleSaved(id: Int) async throws -> Bool {
        try await store.toggleSaved(id: id)
    }

    public func isOnline() async -> Bool {
        await monitor.isOnline
    }

    public func sendTelemetry(_ event: AnalyticsEvent) async {
        Telemetry.shared.send(event)
    }

    /// Re-publish the saved-recipes home-screen widget snapshot (US-17 /
    /// AC-17.3, AC-17.6). Called by the view model after every save /
    /// unsave. Fire-and-forget — all error paths are logged inside
    /// ``SavedRecipesWidgetPublisher.publish()``.
    public func publishSavedWidgetSnapshot() async {
        await savedWidgetPublisher?.publish()
    }

    // MARK: - Comments + ratings

    public func fetchRatingSummary(recipeID: Int) async -> RecipeRating {
        // REG-14: never throw — degrade to a zero-valued summary on any
        // failure. The underlying client already handles 401/403/offline
        // that way; this wrapper catches anything that slips past
        // (timeouts, 5xx, decoding hiccups WPRMRatingsClient surfaces).
        do {
            return try await ratingsClient.summary(forRecipeID: recipeID)
        } catch {
            DODLog.network.error("rating summary fetch failed: \(String(describing: error))")
            return RecipeRating(recipeID: recipeID, average: 0, count: 0, userRating: nil)
        }
    }

    public func cachedRatingSummary(recipeID: Int) async -> RecipeRating? {
        do {
            guard let snapshot = try await store.cachedRating(forRecipeID: recipeID) else {
                return nil
            }
            return RecipeRating(
                recipeID: snapshot.recipeID,
                average: snapshot.average,
                count: snapshot.count,
                userRating: snapshot.userRating
            )
        } catch {
            DODLog.persistence.error("cached rating read failed: \(String(describing: error))")
            return nil
        }
    }

    public func cacheRatingSummary(_ summary: RecipeRating) async {
        let snapshot = CachedRatingSnapshot(
            recipeID: summary.recipeID,
            average: summary.average,
            count: summary.count,
            userRating: summary.userRating
        )
        do {
            try await store.cacheRating(snapshot)
        } catch {
            DODLog.persistence.error("cache rating failed: \(String(describing: error))")
        }
    }

    public func postRating(
        recipeID: Int,
        stars: Int,
        name: String,
        email: String
    ) async throws -> RecipeRating {
        let updated = try await ratingsClient.postRating(
            recipeID: recipeID,
            stars: stars,
            authorName: name,
            authorEmail: email
        )
        // Telemetry only AFTER the network call returns successfully (per
        // task spec) — and never carries name/email (AC-15.4).
        await sendTelemetry(.recipeRated(recipeID: recipeID, stars: stars))
        return updated
    }

    public func fetchComments(
        postID: Int,
        page: Int
    ) async throws -> WPCommentsClient.CommentsPage {
        try await commentsClient.comments(forPostID: postID, page: page)
    }

    public func cachedComments(postID: Int) async -> [RecipeComment] {
        do {
            let snapshots = try await store.cachedComments(forPostID: postID)
            return snapshots.map(Self.snapshotToComment)
        } catch {
            DODLog.persistence.error("cached comments read failed: \(String(describing: error))")
            return []
        }
    }

    public func cacheComments(_ comments: [RecipeComment], postID: Int) async {
        let snapshots = comments.map { Self.commentToSnapshot($0, postID: postID) }
        do {
            try await store.cacheComments(snapshots)
        } catch {
            DODLog.persistence.error("cache comments failed: \(String(describing: error))")
        }
    }

    public func postComment(
        postID: Int,
        body: String,
        name: String,
        email: String,
        rating: Int?
    ) async throws -> RecipeComment {
        let posted = try await commentsClient.postComment(
            postID: postID,
            authorName: name,
            authorEmail: email,
            content: body,
            ratingValue: rating
        )
        // Telemetry only AFTER the network call returns. `awaitingApproval`
        // mirrors WP's `hold` (or anything not explicitly `approved`).
        await sendTelemetry(
            .recipeCommentSubmitted(
                recipeID: postID,
                awaitingApproval: posted.status != .approved
            )
        )
        return posted
    }

    public func loadGuestIdentity() async -> (name: String, email: String)? {
        do {
            guard let identity = try guestIdentity.load() else { return nil }
            return (name: identity.displayName, email: identity.email)
        } catch {
            DODLog.persistence.error("guest identity load failed: \(String(describing: error))")
            return nil
        }
    }

    public func saveGuestIdentity(name: String, email: String) async throws {
        try guestIdentity.save(GuestIdentity(displayName: name, email: email))
    }

    // MARK: - User profile (US-44 / DUT-36 Phase c)

    /// US-44 / CL-138 — read the on-device profile through the injected
    /// store. `nil` if no store was wired (test-only) or no profile has
    /// been saved (the guest-mode default). The ``RecipeDetailViewModel``
    /// uses this for `hasProfile` gating of the Ratings & Reviews write
    /// surface.
    public func loadUserProfile() async -> UserProfile? {
        await profileStore?.load()
    }

    // MARK: - Snapshot bridging

    /// Convert the persistence-layer snapshot to the Domain comment type.
    /// Wave-1 sub 3 deliberately kept `CachedComment` independent of the
    /// Domain type (timing decoupling); we stitch them together here.
    static func snapshotToComment(_ snapshot: CachedCommentSnapshot) -> RecipeComment {
        RecipeComment(
            id: snapshot.id,
            postID: snapshot.postID,
            parentID: snapshot.parentID,
            authorName: snapshot.authorName,
            avatarURL: snapshot.avatarURLString.flatMap { URL(string: $0) },
            dateGMT: snapshot.dateGMT,
            body: snapshot.bodyText,
            ratingValue: snapshot.ratingValue,
            status: RecipeComment.Status(rawValue: snapshot.statusRaw) ?? .unknown
        )
    }

    /// Inverse of ``snapshotToComment(_:)``. `postID` is taken from the
    /// caller because the WP DTO carries it on every row, but the Domain
    /// type also stores it — we trust the caller to pass the same id.
    static func commentToSnapshot(_ comment: RecipeComment, postID: Int) -> CachedCommentSnapshot {
        CachedCommentSnapshot(
            id: comment.id,
            postID: postID,
            parentID: comment.parentID,
            authorName: comment.authorName,
            avatarURLString: comment.avatarURL?.absoluteString,
            dateGMT: comment.dateGMT,
            bodyText: comment.body,
            ratingValue: comment.ratingValue,
            statusRaw: comment.status.rawValue,
            cachedAt: .now,
            isPendingFromThisDevice: false
        )
    }
}
