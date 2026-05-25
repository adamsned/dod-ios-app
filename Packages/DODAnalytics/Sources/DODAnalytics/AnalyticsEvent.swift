import Foundation

/// Compile-enforced allowlist of analytics events.
///
/// Constitution §9 caps v1 tracking to this allowlist. Adding a new case
/// here requires a constitution amendment **and** an App Privacy review.
/// The consultant-pass amendment (2026-05-23) added `cookModeStarted` for
/// US-7 (Cook Mode); see spec AC-7.7.
///
/// All payload values are anonymous by design: no PII, no IDFA, no raw user
/// input. Search queries are hashed (spec AC-3.6).
public enum AnalyticsEvent: Sendable, Hashable {

    /// Sent once per cold launch.
    case appOpen

    /// Sent on each top-level screen appearance.
    /// - Parameter name: stable screen identifier (e.g. "feed", "recipe_detail").
    case screenView(name: String)

    /// Recipe detail screen opened.
    case recipeView(recipeID: Int)

    /// Save bookmark tapped on.
    case recipeSaved(recipeID: Int)

    /// Save bookmark tapped off.
    case recipeUnsaved(recipeID: Int)

    /// Finalized search submitted. Query is **hashed** (constitution §9, spec AC-3.6).
    case recipeSearched(queryHash: String)

    /// Share sheet invoked.
    case recipeShared(recipeID: Int)

    /// User opened a saved recipe while the device was offline.
    case offlineRead(recipeID: Int)

    /// Cook Mode (US-7) entered for a recipe. Fires once per recipe per
    /// session — see ``RecipeDetailViewModel.startCookMode()``.
    case cookModeStarted(recipeID: Int)

    /// Star rating submitted for a recipe (US-13). Authorized by CL-21
    /// (constitution §9 allowlist amendment). Payload carries only the
    /// recipe id and the integer 1...5 star value — no raw user input.
    case recipeRated(recipeID: Int, stars: Int)

    /// Comment submitted for a recipe (US-14). Authorized by CL-21
    /// (constitution §9 allowlist amendment). Payload carries the recipe id
    /// and a boolean indicating whether WP held the comment for moderation
    /// (i.e. `status != .approved` on the returned DTO). The comment body
    /// is **never** included.
    case recipeCommentSubmitted(recipeID: Int, awaitingApproval: Bool)

    /// Home-screen widget tap consumed by the host app (US-17 AC-17.9).
    /// Fires from `RootView.handle(widgetLink:)` for every recognized
    /// `dod://` URL the widget extension emits — featured widget face,
    /// saved-widget recipe row, or saved-widget chrome / empty-state
    /// fallback. The kind identifies which widget surface was tapped; the
    /// optional recipe id is the integer WP post id when the tap targeted
    /// a specific recipe (`dod://recipe/<id>`), and `nil` for chrome /
    /// empty-state taps (`dod://saved`, `dod://feed`). No free-text
    /// payload — see constitution §9 allowlist (amended for this event).
    case widgetOpened(kind: WidgetKind, recipeID: Int?)
}

/// Identifier for the widget surface a `widgetOpened` event originated
/// from. Serializes as the lowercase case name (`"featured"` / `"saved"`)
/// on the wire — see ``AnalyticsEvent/payload``.
public enum WidgetKind: String, Sendable, Hashable, CaseIterable {

    /// `FeaturedRecipeWidget` — today's-featured recipe surface
    /// (spec US-9).
    case featured

    /// `SavedRecipesWidget` — saved-recipes surface introduced by
    /// US-17 (T-321). Covers both the per-row recipe tap and the
    /// chrome / empty-state tap that lands on `dod://saved`.
    case saved
}

extension AnalyticsEvent {
    /// Stable event name as sent to the upstream analytics transport.
    public var name: String {
        switch self {
        case .appOpen: "app_open"
        case .screenView: "screen_view"
        case .recipeView: "recipe_view"
        case .recipeSaved: "recipe_saved"
        case .recipeUnsaved: "recipe_unsaved"
        case .recipeSearched: "recipe_searched"
        case .recipeShared: "recipe_shared"
        case .offlineRead: "offline_read"
        case .cookModeStarted: "cook_mode_started"
        case .recipeRated: "recipe_rated"
        case .recipeCommentSubmitted: "recipe_comment_submitted"
        case .widgetOpened: "widget_opened"
        }
    }

    /// String-keyed payload. Keys are stable wire format; never put
    /// user-typed content in values (constitution §9).
    public var payload: [String: String] {
        switch self {
        case .appOpen:
            [:]
        case .screenView(let name):
            ["screen": name]
        case .recipeView(let recipeID):
            ["recipe_id": String(recipeID)]
        case .recipeSaved(let recipeID):
            ["recipe_id": String(recipeID)]
        case .recipeUnsaved(let recipeID):
            ["recipe_id": String(recipeID)]
        case .recipeSearched(let queryHash):
            ["query_hash": queryHash]
        case .recipeShared(let recipeID):
            ["recipe_id": String(recipeID)]
        case .offlineRead(let recipeID):
            ["recipe_id": String(recipeID)]
        case .cookModeStarted(let recipeID):
            ["recipe_id": String(recipeID)]
        case .recipeRated(let recipeID, let stars):
            ["recipe_id": String(recipeID), "stars": String(stars)]
        case .recipeCommentSubmitted(let recipeID, let awaitingApproval):
            ["recipe_id": String(recipeID), "awaiting_approval": String(awaitingApproval)]
        case .widgetOpened(let kind, let recipeID):
            // `kind` is always emitted; `recipe_id` is only emitted when
            // the tap targeted a specific recipe (`dod://recipe/<id>`).
            // Chrome / empty-state taps drop the key entirely rather than
            // sending a sentinel string. Constitution §9: no free text.
            if let recipeID {
                ["kind": kind.rawValue, "recipe_id": String(recipeID)]
            } else {
                ["kind": kind.rawValue]
            }
        }
    }
}
