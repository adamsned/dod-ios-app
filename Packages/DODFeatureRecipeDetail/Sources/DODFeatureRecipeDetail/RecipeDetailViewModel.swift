import DODAnalytics
import DODDomain
import DODNetworking
import DODSupport
import Foundation
import Observation

/// Spec trace: AC-4.* (recipe detail behavior), AC-4.11 (failure path),
/// AC-5.1 (save toggle + undo), AC-5.4 (offline), AC-6.* (share).
@Observable
@MainActor
public final class RecipeDetailViewModel {

    public enum LoadState: Equatable {
        case loadingDetail
        case ready
        /// US-37 / CL-63 / AC-37.3 (T-640): the post lacks parseable JSON-LD
        /// but the article body extracted cleanly. The view renders
        /// `ArticleDetailView` with the carried `Recipe.articleBodyHTML`.
        /// Carries the kind-classified `Recipe` so the view layer has the
        /// hero + title + body + canonical URL it needs to render — same
        /// shape as `.ready`, just a different rendering branch.
        case article(Recipe)
        case unavailable  // AC-4.11 — final fallback (both JSON-LD AND
        // article-body extraction failed).
    }

    /// State machine for the ratings + comments section. `.idle` means
    /// `loadRatingsAndComments()` has not yet been called; `.loading` is
    /// the first network round-trip; `.ready` is the steady state (any
    /// background refresh failure leaves us in `.ready` with whatever the
    /// cache had — REG-14 / AC-14.6); `.error` only fires when both the
    /// cache and the network came back empty/broken.
    public enum CommentsLoadState: Equatable {
        case idle
        case loading
        case ready
        case error(String)
    }

    public let listItem: RecipeListItem
    public let canonicalURL: URL
    // Module-internal setters (`internal(set)`) so the fetch +
    // classification extension in `RecipeDetailViewModel+Fetch.swift`
    // can mutate the load-state machine. Externally these remain
    // read-only — the public surface is unchanged from the pre-T-640
    // shape callers consume.
    public internal(set) var recipe: Recipe?
    public internal(set) var related: [RecipeListItem] = []
    public internal(set) var loadState: LoadState = .loadingDetail
    public private(set) var isSaved: Bool = false
    /// US-35 / AC-35.1 — `internal(set)` for the `+Download` extension.
    public internal(set) var isDownloaded: Bool = false
    public private(set) var checkedIngredientIDs: Set<UUID> = []
    public internal(set) var snackbarMessage: String?
    /// T-732 / CL-129 / AC-4.12: rich blocks for the recipe's narrative
    /// blurb (the prose preceding the WPRM recipe card). Populated by the
    /// fetch path. T-733 / CL-130: capped to 1-2 paragraphs via the
    /// extractor's `paragraphLimit`; ``hasExpandableBlurb`` (in
    /// `RecipeDetailViewModel+Blurb.swift`) is the visibility gate.
    public internal(set) var blurbBlocks: [ArticleBlock] = []

    // MARK: - Servings scaler (US-31)

    /// Current user-selected serving count. Defaults to the recipe's source
    /// `recipeYield` once the detail loads; stays at the AC-31.3 default
    /// sentinel `4` until then. AC-31.1 / AC-31.2 / AC-31.3 / AC-31.8.
    public private(set) var userServings: Int = RecipeDetailViewModel.defaultServings
    /// Servings stepper range (AC-31.2). 1..24 — single serving up to
    /// roughly 4× a typical 6-serving recipe.
    public let userServingsRange: ClosedRange<Int> = 1...24
    /// Fallback default when the recipe hasn't loaded yet or didn't
    /// publish a `recipeYield` block (AC-31.3 second sentence).
    public static let defaultServings: Int = 4

    // MARK: - Comments + ratings state (US-13/14/15)

    public private(set) var ratingSummary: RecipeRating?
    // `internal(set)` (not `private(set)`) so the comment-submit path in
    // `RecipeDetailViewModel+CommentSubmit.swift` can mutate the visible
    // thread + draft + in-flight flag after extraction (DUT-7). Public
    // read-only contract is unchanged — external callers still can't write.
    public internal(set) var comments: [RecipeComment] = []
    public private(set) var commentsLoadState: CommentsLoadState = .idle
    /// Current selection in the `StarRatingInput` before the user taps
    /// "Submit rating". 0 means "no selection".
    public private(set) var pendingUserRating: Int = 0
    public internal(set) var commentDraft: String = ""
    public internal(set) var isSubmittingComment: Bool = false
    public private(set) var isSubmittingRating: Bool = false
    /// True when the Keychain has no guest identity yet — the view layer
    /// uses this to gate the rating / composer affordances behind the
    /// non-dismissible `GuestIdentitySheet` (AC-15.1).
    public var requiresGuestIdentity: Bool = true

    /// Tracks whether `cookModeStarted` has already been sent this session
    /// for this recipe, so re-entering Cook Mode in the same view session
    /// fires at most one telemetry event (spec AC-7.7).
    private var cookModeTelemetrySentThisSession: Bool = false

    /// Internal so the fetch + classification extension (in
    /// `RecipeDetailViewModel+Fetch.swift`, T-640) and the US-35
    /// `+Download` extension (T-620) can read it. The dependency
    /// surface is otherwise private to the view-model module.
    let dependencies: RecipeDetailDependencies

    public init(
        listItem: RecipeListItem,
        canonicalURL: URL,
        dependencies: RecipeDetailDependencies
    ) {
        self.listItem = listItem
        self.canonicalURL = canonicalURL
        self.dependencies = dependencies
    }

    public var isOffline: Bool {
        get async { await !dependencies.isOnline() }
    }

    public func onAppear() async {
        // Telemetry per AC and constitution §9.
        await dependencies.sendTelemetry(.recipeView(recipeID: listItem.id))
        isSaved = (try? await dependencies.isSaved(id: listItem.id)) ?? false
        isDownloaded = (try? await dependencies.isDownloaded(id: listItem.id)) ?? false
        // Step 1: hydrate from cache if present (fast path).
        if let cached = try? await dependencies.cachedRecipe(id: listItem.id), cached.hasDetail {
            recipe = cached
            // US-37 / CL-63 / AC-37.3 (T-640): articles route to `.article`;
            // recipes use the `.ready` + related-strip path (no related
            // strip on articles per CL-63 decision 5).
            // T-736 / CL-133: cache-hit recipe path also fires a background
            // `refreshBlurbBlocks` — see helper for the contract.
            switch cached.kind {
            case .recipe: await hydrateCachedRecipe(cached)
            case .article: loadState = .article(cached)
            }
        } else {
            // Step 2: try fetch + parse.
            await fetchAndParse()
        }
        // Step 3: layer the ratings + comments load on top. This MUST run
        // after the recipe path above so the screen renders content
        // immediately and the comments section appears once it's ready
        // — never blocking the recipe load itself (US-13/14 integration).
        await loadRatingsAndComments()
    }

    // MARK: - Comments + ratings (US-13/14/15)

    /// Populate `ratingSummary` and `comments` from the local cache
    /// immediately for the offline-first read, then refresh from the
    /// network in the background. Network failures leave the cached
    /// state in place per REG-14 / AC-14.6.
    public func loadRatingsAndComments() async {
        // Refresh the guest-identity gate so the view picks up a
        // previously-saved identity (e.g. the user rated a different
        // recipe earlier this session).
        requiresGuestIdentity = await dependencies.loadGuestIdentity() == nil

        commentsLoadState = .loading

        // Step 1: fast path — cached values.
        if let cachedRating = await dependencies.cachedRatingSummary(recipeID: listItem.id) {
            ratingSummary = cachedRating
            // If the cache already remembers this device's userRating,
            // seed the input so the user can "Edit" without retyping.
            if let userRating = cachedRating.userRating, pendingUserRating == 0 {
                pendingUserRating = userRating
            }
        }
        let cachedComments = await dependencies.cachedComments(postID: listItem.id)
        if !cachedComments.isEmpty {
            comments = cachedComments
            commentsLoadState = .ready
        }

        // Step 2: network refresh (best-effort).
        let fresh = await dependencies.fetchRatingSummary(recipeID: listItem.id)
        ratingSummary = fresh
        await dependencies.cacheRatingSummary(fresh)

        do {
            let page = try await dependencies.fetchComments(postID: listItem.id, page: 1)
            // Show approved comments only per AC-14.2.
            let approved = page.comments.filter { $0.status == .approved }
            comments = approved
            await dependencies.cacheComments(approved, postID: listItem.id)
            commentsLoadState = .ready
        } catch {
            DODLog.network.error("comments fetch failed: \(String(describing: error))")
            // If we already hydrated from cache, stay in `.ready` so the
            // user keeps seeing the cached thread (AC-14.6). Only surface
            // `.error` when we have nothing to show.
            if comments.isEmpty {
                commentsLoadState = .error("Couldn't load comments.")
            }
        }
    }

    public func setPendingRating(_ stars: Int) {
        pendingUserRating = stars
    }

    public func setCommentDraft(_ text: String) {
        commentDraft = text
    }

    /// Submit a star rating. Gated behind the guest-identity sheet —
    /// callers should check `requiresGuestIdentity` first and present
    /// `GuestIdentitySheet` if true. AC-13.2 / AC-13.3 / AC-13.5.
    public func submitRating(stars: Int) async {
        guard (1...5).contains(stars) else { return }
        guard let identity = await dependencies.loadGuestIdentity() else {
            // Caller should have presented the sheet; flip the gate so
            // the next render presents it.
            requiresGuestIdentity = true
            return
        }
        isSubmittingRating = true
        defer { isSubmittingRating = false }

        do {
            let updated = try await dependencies.postRating(
                recipeID: listItem.id,
                stars: stars,
                name: identity.name,
                email: identity.email
            )
            ratingSummary = updated
            pendingUserRating = stars
            await dependencies.cacheRatingSummary(updated)
            snackbarMessage = "Thanks for rating."
        } catch {
            DODLog.network.error("post rating failed: \(String(describing: error))")
            snackbarMessage = "Couldn't save your rating — try again."
        }
    }

    // `submitComment()` lives in `RecipeDetailViewModel+CommentSubmit.swift`
    // (extracted with the DUT-7 author-identity guard so this file stays
    // under the SwiftLint 400-line `file_length` cap — same pattern as the
    // `+CommentSnackbar` / `+Fetch` extensions).

    /// Persist the captured display name + email and unblock the pending
    /// rate / post action. AC-15.2.
    public func saveGuestIdentityAndContinue(name: String, email: String) async {
        do {
            try await dependencies.saveGuestIdentity(name: name, email: email)
            requiresGuestIdentity = false
        } catch {
            DODLog.persistence.error("save guest identity failed: \(String(describing: error))")
            snackbarMessage = "Couldn't save your identity — try again."
        }
    }

    public func toggleIngredient(_ id: UUID) {
        if checkedIngredientIDs.contains(id) {
            checkedIngredientIDs.remove(id)
        } else {
            checkedIngredientIDs.insert(id)
        }
    }

    public func toggleSaved() async {
        do {
            let nowSaved = try await dependencies.toggleSaved(id: listItem.id)
            isSaved = nowSaved
            if nowSaved {
                await dependencies.sendTelemetry(.recipeSaved(recipeID: listItem.id))
                snackbarMessage = "Saved for offline."
            } else {
                await dependencies.sendTelemetry(.recipeUnsaved(recipeID: listItem.id))
                snackbarMessage = "Removed from saved."
            }
            // Refresh the saved-recipes home-screen widget snapshot so its
            // timeline reflects the new state without waiting for
            // WidgetKit's default 15-minute refresh (US-17 / AC-17.3 +
            // AC-17.6). Fire-and-forget; errors are logged inside the
            // dependency, never thrown.
            await dependencies.publishSavedWidgetSnapshot()
        } catch {
            DODLog.persistence.error("toggle save failed: \(String(describing: error))")
        }
    }

    public func didShare() async {
        await dependencies.sendTelemetry(.recipeShared(recipeID: listItem.id))
    }

    /// Called when the user taps the Cook Now CTA (spec AC-7.1). Sends the
    /// `cookModeStarted` telemetry event the first time per recipe per
    /// session (AC-7.7), no-ops on subsequent entries within the same
    /// detail-screen lifetime.
    public func didTapCookMode() async {
        guard !cookModeTelemetrySentThisSession else { return }
        cookModeTelemetrySentThisSession = true
        await dependencies.sendTelemetry(.cookModeStarted(recipeID: listItem.id))
    }

    /// Merges back the ingredient check set from Cook Mode's drawer so
    /// state round-trips into the underlying detail screen (AC-7.5).
    public func mergeIngredientChecks(_ ids: Set<UUID>) {
        checkedIngredientIDs = ids
    }

    // MARK: - Servings scaler (US-31)

    /// Source serving count from the JSON-LD `recipeYield`. Falls back to
    /// ``defaultServings`` if the recipe hasn't parsed yet or didn't ship
    /// a yield value. Spec trace: AC-31.3, AC-4.11.
    public var sourceServings: Int {
        recipe?.servings ?? Self.defaultServings
    }

    /// Multiplier the view layer applies to ingredient quantities at
    /// render time. AC-31.4. The source ``Recipe`` model is never
    /// mutated — this is pure presentation logic (AC-31.8).
    public var servingsScaleFactor: Double {
        let source = max(sourceServings, 1)
        return Double(userServings) / Double(source)
    }

    /// True when the user has scaled past the threshold where a home
    /// 5-quart dutch oven becomes a physical-capacity concern.
    /// Spec trace: AC-31.6 (warning copy), CL-52 (threshold rationale).
    public var shouldShowServingWarning: Bool {
        FractionRenderer.shouldShowDutchOvenWarning(forServings: userServings)
    }

    /// Adjust the user's serving count (clamped to ``userServingsRange``).
    /// Called from the stepper's `value` binding. AC-31.7: changing the
    /// serving count never clears ``checkedIngredientIDs`` — the user's
    /// in-progress check state survives a scale.
    public func setUserServings(_ count: Int) {
        userServings = clampToRange(count)
    }

    /// Sync ``userServings`` to the source servings once the recipe has
    /// parsed. Called from the view after `loadState` reaches `.ready`.
    /// Idempotent — re-syncing while already aligned is a no-op so the
    /// user's manual stepper changes aren't clobbered by a late refresh.
    public func resetServingsToSourceIfFirstLoad() {
        guard userServings == Self.defaultServings, sourceServings != Self.defaultServings else {
            return
        }
        userServings = clampToRange(sourceServings)
    }

    /// Clamp `count` to ``userServingsRange``. Centralized so the setter
    /// and the source-sync path agree on bounds.
    private func clampToRange(_ count: Int) -> Int {
        min(max(count, userServingsRange.lowerBound), userServingsRange.upperBound)
    }

    public func dismissSnackbar() {
        snackbarMessage = nil
    }

    // Fetch + JSON-LD + article-classification helpers live in
    // ``RecipeDetailViewModel+Fetch.swift`` (US-37 / CL-63 / T-640
    // extension), extracted to keep this type under the SwiftLint
    // body-length cap.
}
