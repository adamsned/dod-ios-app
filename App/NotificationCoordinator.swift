import DODFeatureFeed
import DODSupport
import Foundation
import UserNotifications

/// `UNUserNotificationCenterDelegate` for the app's local notifications
/// (spec US-42 / AC-42.3 + AC-42.5).
///
/// Two responsibilities:
/// - **Foreground banner (AC-42.5):** `willPresent` opts into showing the
///   banner + sound while the app is foregrounded, so a notification that
///   fires while the app is open is observable rather than silently
///   swallowed (important for the simulator test).
/// - **Tap routing (AC-42.3):** `didReceive` reads the `dod://…` deep-link
///   string from `userInfo` (under ``NotificationPlan/deepLinkKey``), parses
///   it through the shared `DeepLinkIntent.parse` — the same parser
///   `RootView.onOpenURL` runs App Intents / Spotlight URLs through (US-10) —
///   and routes the resulting intent through `DeepLinkDispatcher`, so a
///   tapped notification opens the post exactly the way a widget tap or a
///   Spotlight result does. **No new URL grammar.** The notification's own
///   `dod://article/<id>` grammar (DUT-566) round-trips through that shared
///   parser, which maps both `dod://recipe/<id>` and `dod://article/<id>` to
///   `.openRecipe(id:)`: `PostKind` lives on the `Recipe` domain type
///   (US-37 / CL-63), so the detail view model classifies recipe-vs-article
///   itself once the post is resolved. A private `postID(fromDeepLink:)`
///   remains only as a last-resort fallback for any well-formed `dod://…/<id>`
///   URL the shared parser doesn't recognize.
///
/// `NSObject` subclass because `UNUserNotificationCenterDelegate` is an
/// Objective-C protocol. Set as the center's delegate in `AppDelegate`.
final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {

    /// AC-42.5 — present the banner while foregrounded.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    /// AC-42.3 — route the tapped notification's deep link.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let userInfo = response.notification.request.content.userInfo
        guard
            let urlString = userInfo[NotificationPlan.deepLinkKey] as? String,
            let intent = Self.intent(fromDeepLink: urlString)
        else {
            DODLog.app.error("notification tap: no routable deep link in userInfo")
            return
        }
        // Reuse the existing dispatcher (US-10) — RootView observes
        // `pending` and resolves the route from the cache. Works for both
        // recipe and article kinds (PostKind lives on Recipe).
        Task { @MainActor in DeepLinkDispatcher.shared.dispatch(intent) }
    }

    /// Maps a notification's `dod://…` deep-link string to the `DeepLinkIntent`
    /// the dispatcher routes on. DUT-566 — this runs the string through the
    /// shared `DeepLinkIntent.parse` so the notification grammar
    /// (`dod://recipe/<id>` and `dod://article/<id>`) round-trips through the
    /// exact path `RootView.onOpenURL` uses. If the shared parser doesn't
    /// recognize the URL, it falls back to the private `postID(fromDeepLink:)`
    /// hand-parser (mapping to `.openRecipe(id:)`) so no previously-working
    /// payload regresses. Returns `nil` only when both fail.
    static func intent(fromDeepLink urlString: String) -> DeepLinkIntent? {
        if let url = URL(string: urlString), let intent = DeepLinkIntent.parse(url) {
            return intent
        }
        guard let id = postID(fromDeepLink: urlString) else { return nil }
        return .openRecipe(id: id)
    }

    /// Extracts the integer post id from a `dod://recipe/<id>` or
    /// `dod://article/<id>` deep link. Returns `nil` for any URL that
    /// doesn't carry a positive integer id so a malformed payload is
    /// ignored rather than crashing. Fallback only — see
    /// ``intent(fromDeepLink:)``.
    static func postID(fromDeepLink urlString: String) -> Int? {
        guard
            let url = URL(string: urlString),
            url.scheme?.lowercased() == "dod"
        else { return nil }
        let trimmed = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let id = Int(trimmed), id > 0 else { return nil }
        return id
    }
}
