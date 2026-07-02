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

    /// Voice Mode (US-40) toggled on or off inside Cook Mode. Authorized by
    /// CL-83 (constitution §9 allowlist amendment) for AC-40.8. Payload carries
    /// a single boolean — no recipe id, no free text. A device-state / usage
    /// event in the same spirit as the idle-timer toggle, but unlike that one
    /// it *is* surfaced as an allowlisted event (the user-driven on/off is a
    /// product-interaction signal worth tracking).
    case voiceModeToggled(on: Bool)

    /// A Siri voice command (US-40 / AC-40.5) fired against the active Cook
    /// Mode session. Authorized by CL-83. The payload carries only the fixed
    /// ``VoiceCommandName`` enum string identifying which command ran — the
    /// user's raw spoken phrase is **never** included (the intent layer never
    /// sees it: SiriKit matches the phrase and hands the app a typed intent).
    case voiceCommandFired(command: VoiceCommandName)

    /// iCloud Sync (US-41) turned ON — via the AC-41.2 first-launch opt-in
    /// prompt (T-704) or the AC-41.3 Settings toggle (T-703). Empty payload:
    /// sync is a session-level state, not a per-recipe action (`recipeSaved`
    /// already covers per-recipe granularity). Authorized by CL-124
    /// (constitution §9 allowlist amendment). Spec: AC-41.9 (T-707).
    case syncEnabled

    /// iCloud Sync (US-41) turned OFF — via the AC-41.3 Settings toggle only
    /// (the prompt's "Not now" declines without ever disabling). Empty
    /// payload. Authorized by CL-124. Spec: AC-41.9 (T-707).
    case syncDisabled

    /// A CloudKit sync round-trip completed successfully (US-41 / AC-41.9),
    /// debounced upstream to at most once per 60s so a burst of mirror events
    /// never spams the transport. Empty payload. Authorized by CL-124. The
    /// dispatch site (observing `NSPersistentCloudKitContainer` events) lands
    /// with T-705's sync-status machinery; T-707 defines the event.
    case syncCompletedSuccessfully

    /// A CloudKit sync attempt failed after the AC-41.6 retry budget (US-41 /
    /// AC-41.9). The payload carries only the closed-set ``SyncErrorCategory``
    /// string — never the raw `CKError` code/message (constitution §9: no free
    /// text / no PII). Authorized by CL-124. Dispatch lands with T-705.
    case syncFailed(errorCategory: SyncErrorCategory)
}

/// The closed set of Siri voice commands Cook Mode exposes (US-40 / AC-40.5).
/// Serializes as the lowercase raw value on the analytics wire — a fixed
/// enum string, not user input, so it satisfies the constitution §9 "no free
/// text" rule the same way ``WidgetKind`` does for `widgetOpened`.
public enum VoiceCommandName: String, Sendable, Hashable, CaseIterable {

    /// "next step" / "next" / "go forward" — advances one step.
    case next

    /// "previous step" / "go back" / "back" — steps back one.
    case previous

    /// "repeat" / "say that again" — re-reads the current step.
    case `repeat`

    /// "pause" — pauses the current utterance.
    case pause

    /// "resume" / "continue" — resumes a paused utterance (DUT-343).
    case resume
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

    /// Cooking Tip widget (inline + home-screen small/medium) — a
    /// `dod://tip/<index>` tap that opens the full tip in a dialog
    /// (DUT-457 / DUT-459).
    case cookingTip
}

/// Closed-set category for a `syncFailed` event (US-41 / AC-41.9). The wire
/// value is the case name — **never** the raw `CKError` code or message
/// (constitution §9: no free text, no PII). Mirrors the closed-enum posture
/// of ``WidgetKind`` + ``VoiceCommandName``.
public enum SyncErrorCategory: String, Sendable, Hashable, CaseIterable {

    /// No connectivity / transient network failure.
    case network

    /// iCloud account unavailable (`.noAccount` / `.restricted`).
    case accountStatus

    /// The user's iCloud storage quota is exhausted.
    case quotaExceeded

    /// A CloudKit server-side internal error.
    case serverInternal

    /// Any other / uncategorized failure (the catch-all so the closed set
    /// never needs a free-text escape hatch).
    case other
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
        case .voiceModeToggled: "voice_mode_toggled"
        case .voiceCommandFired: "voice_command_fired"
        case .syncEnabled: "sync_enabled"
        case .syncDisabled: "sync_disabled"
        case .syncCompletedSuccessfully: "sync_completed_successfully"
        case .syncFailed: "sync_failed"
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
        case .voiceModeToggled(let on):
            ["on": String(on)]
        case .voiceCommandFired(let command):
            // `command` is a closed enum string (next/previous/repeat/pause),
            // never the user's spoken phrase. Constitution §9: no free text.
            ["command": command.rawValue]
        case .syncEnabled:
            [:]
        case .syncDisabled:
            [:]
        case .syncCompletedSuccessfully:
            [:]
        case .syncFailed(let errorCategory):
            // Closed-set category only — never the raw CKError. Constitution §9.
            ["error_category": errorCategory.rawValue]
        }
    }
}
