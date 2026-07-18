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
    /// DUT-544: whether the page's JSON-LD carries a `@type: Recipe` node — the
    /// "this page's SUBJECT is a recipe" signal used to gate the recipe path so
    /// a round-up ARTICLE that merely embeds a WPRM card isn't mis-rendered as a
    /// bare recipe. Default routes to
    /// ``DODNetworking/JSONLDRecipeParser/hasRecipeJSONLD(html:)``; tests
    /// override to model recipe vs. article pages.
    func hasRecipeJSONLD(html: String) -> Bool
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
    // Required surface: `isDownloaded(id:) async throws -> Bool`,
    // `downloadForOffline(recipe:) async throws -> DownloadOutcome`, +
    // `removeDownload(id:) async throws` (T-775 / DUT-81 — the inverse).

    func isDownloaded(id: Int) async throws -> Bool
    func downloadForOffline(recipe: Recipe) async throws -> DownloadOutcome
    func removeDownload(id: Int) async throws

    // MARK: - Cooking Journal (US-48 / DUT-326)

    /// Append one completed cook to the private Cooking Journal (DUT-326 — the
    /// Cook Mode "Add to Cooking Journal" action on the Done card). Routes to
    /// ``RecipeStore/logCook(_:)``. Logging counts toward rank — intentional,
    /// this is a real completed cook. Default no-op so existing fakes keep
    /// compiling; only ``LiveRecipeDetailDependencies`` actually persists.
    func logCook(_ entry: CookLogEntry) async throws

    /// DUT-208 — delete an orphaned cook photo whose journal write failed. Cook
    /// Mode persists the photo to ``CookPhotoStore`` before ``logCook(_:)``; when
    /// that throws, no row references its `photoLocalID`, so the DUT-338 cleanup
    /// can't reach it. Default no-op so existing fakes keep compiling; the live
    /// wiring routes to ``CookPhotoStore/delete(id:)``.
    func deleteCookPhoto(id: String) async

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

    /// DUT-387 — persist a just-submitted held (non-approved) comment into the
    /// **pending** bucket (`isPendingFromThisDevice: true`), NOT as a normal
    /// public row. A pending row is filtered from the public reader UI and is
    /// overwritten to approved when a later fetch returns it; caching it as a
    /// normal row (via ``cacheComments(_:postID:)``) leaves a rejected comment
    /// stuck in the cache forever. A default no-op keeps fakes compiling.
    func cachePendingComment(_ comment: RecipeComment, postID: Int) async

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

    // MARK: - User profile (US-44 / DUT-36 Phase c, CL-138)
    //
    // Backs the Ratings & Reviews write-surface gate. Defaults +
    // live impls live in `RecipeDetailDependencies+Profile.swift`.
    // `loadUserProfile` drives `RecipeDetailViewModel.hasProfile`; the
    // two `*ForGate` accessors surface the store references the
    // section view hands to `ProfileEditView` when the gate CTA fires.

    func loadUserProfile() async -> UserProfile?
    var profileStoreForGate: (any ProfileStoring)? { get }
    #if canImport(UIKit)
    var profilePhotoStoreForGate: (any ProfilePhotoStoring)? { get }
    #endif

    // MARK: - Daddy Mode (Phase 1, cosmetic) — own-comment Cook Rank + owner
    //
    // Two narrow reads that let the ratings section attach the CURRENT user's
    // Cook Rank (+ owner badge) to their OWN comment rows. Defaults + live impls
    // live in `RecipeDetailDependencies+Profile.swift`. Both are safe no-ops by
    // default so existing fakes keep compiling; display-only, authorize nothing.

    /// The local rank-ladder cook count (`CookLogStats.rankLadderCookCount`),
    /// which `CookProgression.currentRank` maps to the user's Cook Rank.
    func loadRankLadderCookCount() async -> Int
    /// The current signed-in user's Sign in with Apple `sub`, fed to
    /// `OwnerGate.isOwner` to decide the owner badge.
    var currentUserIdentifier: String? { get }

    // MARK: - Add to Shopping List (US-39 / DUT-534)

    /// DUT-534 — append this recipe's ingredients to the Shopping List. Recipe
    /// Detail carries a fully-loaded `recipe` (ingredients populated), so no
    /// hydration happens here; the live wiring routes to
    /// `DODFeatureSaved.LiveShoppingListAppender` (App-Group store), which this
    /// package can't import directly — hence the seam. Returns the appended-row
    /// count / `.couldntLoad` so the view model picks the Snackbar copy. Default
    /// `.couldntLoad` so fakes that don't model the list keep compiling — the
    /// default impl lives in the extension below.
    func addToShoppingList(_ recipe: Recipe) async -> AddToShoppingListResult

    // MARK: - Handwritten annotations (iPad + Apple Pencil, v2)
    //
    // Per-recipe PencilKit drawing persistence. Defaults + the live file-store
    // routing live in `RecipeDetailDependencies+Annotations.swift`. The record
    // is Foundation-only `Data` (see ``DODPersistence/RecipeAnnotationRecord``),
    // so this seam stays platform-agnostic; the `PKDrawing` ⇄ `Data` conversion
    // happens in the iOS-guarded view layer. Defaults are safe no-ops so every
    // existing fake keeps compiling.
    func loadRecipeAnnotation(recipeID: Int) async -> RecipeAnnotationRecord?
    func saveRecipeAnnotation(_ record: RecipeAnnotationRecord, recipeID: Int) async
}

extension RecipeDetailDependencies {
    /// Default no-op so existing fakes (e.g. `FakeRecipeDetailDependencies`
    /// in the test suite) don't have to opt in to widget publishing. The
    /// live wiring overrides this — see ``LiveRecipeDetailDependencies``.
    public func publishSavedWidgetSnapshot() async {}

    /// DUT-326 — default no-op so fakes that don't model the journal keep
    /// compiling. ``LiveRecipeDetailDependencies`` overrides to route to
    /// ``RecipeStore/logCook(_:)``.
    public func logCook(_ entry: CookLogEntry) async throws {}

    /// DUT-208 — default no-op so fakes that don't model photo cleanup keep
    /// compiling. ``LiveRecipeDetailDependencies`` overrides to route to
    /// ``CookPhotoStore/delete(id:)``.
    public func deleteCookPhoto(id: String) async {}

    /// DUT-387 — default no-op so fakes that don't model the pending-comment
    /// bucket keep compiling. ``LiveRecipeDetailDependencies`` overrides to
    /// route to ``RecipeStore/upsertPendingComment(_:)``.
    public func cachePendingComment(_ comment: RecipeComment, postID: Int) async {}

    /// DUT-534 — default `.couldntLoad` so fakes that don't model the Shopping
    /// List keep compiling. ``LiveRecipeDetailDependencies`` overrides to route
    /// to `DODFeatureSaved.LiveShoppingListAppender` via the App-wired closure.
    public func addToShoppingList(_ recipe: Recipe) async -> AddToShoppingListResult {
        .couldntLoad
    }

    // US-44 / CL-138 / DUT-36 Phase c profile-gate defaults
    // (`loadUserProfile()`, `profileStoreForGate`,
    // `profilePhotoStoreForGate`) live in
    // `RecipeDetailDependencies+Profile.swift` — extracted so this
    // file stays under the SwiftLint 400-line `file_length` cap.

    /// US-37 / CL-63 / AC-37.2 (T-640) + DOD-ART-1: default routes to
    /// ``DODSupport/ArticleBodyExtractor/extractContentHTML(html:)`` so
    /// production callers get the rich-rendering **HTML** body (parsed into
    /// native blocks by ``DODSupport/ArticleHTMLParser`` in
    /// ``ArticleDetailView``). Tests override this to return a canned body
    /// (or empty string to exercise the unavailable fallback).
    public func extractArticleBody(html: String) -> String {
        ArticleBodyExtractor.extractContentHTML(html: html)
    }

    /// DUT-544 — default routes to the JSON-LD parser's recipe-node detection
    /// so production callers get the real subject signal. Tests override to
    /// model a recipe page (`true`) vs. a round-up article (`false`).
    public func hasRecipeJSONLD(html: String) -> Bool {
        JSONLDRecipeParser.hasRecipeJSONLD(html: html)
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
    /// US-44 / CL-138 / DUT-36 Phase c — Phase a Keychain profile
    /// store (and Phase b photo store) routed in by `AppDependencies`
    /// so the Ratings & Reviews gate can read `hasProfile` and hand
    /// the stores to ``ProfileEditView`` from the gate CTA. Optional
    /// for terse test wiring.
    let profileStore: (any ProfileStoring)?
    #if canImport(UIKit)
    let profilePhotoStore: (any ProfilePhotoStoring)?
    #endif
    let imageLoader: ImageLoader
    private let savedWidgetPublisher: SavedRecipesWidgetPublisher?

    /// DUT-534 — the App-wired append seam. `LiveRecipeDetailDependencies` lives
    /// in `DODFeatureRecipeDetail`, which does NOT depend on `DODFeatureSaved`
    /// (where the appender + App-Group store are), so the App composition root
    /// injects `LiveShoppingListAppender.addToShoppingList` as this closure. The
    /// method below routes to it. `nil` (the default) means the seam isn't wired
    /// (previews / terse tests) → the action reports `.couldntLoad`.
    let appendToShoppingList: (@Sendable (Recipe) async -> AddToShoppingListResult)?

    #if canImport(UIKit)
    public init(
        client: WPRestClient,
        fetcher: RecipePageFetcher,
        store: RecipeStore,
        monitor: NetworkMonitor,
        commentsClient: WPCommentsClient,
        ratingsClient: WPRMRatingsClient,
        guestIdentity: any GuestIdentityStoring,
        profileStore: (any ProfileStoring)? = nil,
        profilePhotoStore: (any ProfilePhotoStoring)? = nil,
        imageLoader: ImageLoader = ImageLoader(),
        savedWidgetPublisher: SavedRecipesWidgetPublisher? = nil,
        appendToShoppingList: (@Sendable (Recipe) async -> AddToShoppingListResult)? = nil
    ) {
        self.client = client
        self.fetcher = fetcher
        self.store = store
        self.monitor = monitor
        self.commentsClient = commentsClient
        self.ratingsClient = ratingsClient
        self.guestIdentity = guestIdentity
        self.profileStore = profileStore
        self.profilePhotoStore = profilePhotoStore
        self.imageLoader = imageLoader
        // Default to a publisher rooted in the same store + the live App
        // Group; callers can pass nil to disable the side effect for
        // unit-test wiring that doesn't care about widgets.
        self.savedWidgetPublisher = savedWidgetPublisher ?? SavedRecipesWidgetPublisher(store: store)
        self.appendToShoppingList = appendToShoppingList
    }
    #else
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
        savedWidgetPublisher: SavedRecipesWidgetPublisher? = nil,
        appendToShoppingList: (@Sendable (Recipe) async -> AddToShoppingListResult)? = nil
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
        self.savedWidgetPublisher = savedWidgetPublisher ?? SavedRecipesWidgetPublisher(store: store)
        self.appendToShoppingList = appendToShoppingList
    }
    #endif

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

    // US-13/14/15 — WPRM ratings + WP comments + guest identity live
    // impls live in `RecipeDetailDependencies+CommentsRatings.swift`.
    // US-44 / CL-138 — Phase c profile-gate live impls live in
    // `RecipeDetailDependencies+Profile.swift`. Snapshot-bridging
    // helpers live in `RecipeDetailDependencies+SnapshotBridging.swift`.
    // The split keeps this file under the SwiftLint 400-line
    // `file_length` cap.
}
