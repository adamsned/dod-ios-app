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

    /// Save heart tapped on.
    case recipeSaved(recipeID: Int)

    /// Save heart tapped off.
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
        }
    }
}
