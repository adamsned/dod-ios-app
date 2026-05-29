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
///   string from `userInfo` (under ``NotificationPlan/deepLinkKey``),
///   extracts the integer post id, and routes through the existing
///   `DeepLinkDispatcher` — the same dispatcher App Intents / Spotlight
///   use (US-10) — so a tapped notification opens the post exactly the way
///   a widget tap or a Spotlight result does. **No new URL grammar.**
///   Routing by id (rather than re-opening the URL) handles both
///   `dod://recipe/<id>` and `dod://article/<id>` uniformly: `PostKind`
///   lives on the `Recipe` domain type (US-37 / CL-63), so the detail view
///   model classifies recipe-vs-article itself once the post is resolved.
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
            let id = Self.postID(fromDeepLink: urlString)
        else {
            DODLog.app.error("notification tap: no routable deep link in userInfo")
            return
        }
        // Reuse the existing dispatcher (US-10) — RootView observes
        // `pending` and resolves the route from the cache. Works for both
        // recipe and article kinds (PostKind lives on Recipe).
        DeepLinkDispatcher.shared.dispatch(.openRecipe(id: id))
    }

    /// Extracts the integer post id from a `dod://recipe/<id>` or
    /// `dod://article/<id>` deep link. Returns `nil` for any URL that
    /// doesn't carry a positive integer id so a malformed payload is
    /// ignored rather than crashing.
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
