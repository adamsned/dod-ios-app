import DODDomain
import DODNetworking
import DODSupport
import Foundation

/// Background poll that detects newly-published WordPress posts and
/// schedules a local notification for each one (DUT-938).
///
/// The notification *infrastructure* (`NotificationService`,
/// `NotificationCoordinator`, the Settings toggle) already existed with no
/// trigger — nothing ever called
/// `NotificationService.scheduleNewPostNotification(title:postKind:recipeID:)`.
/// This poller is that missing trigger: it is invoked from a
/// `BGAppRefreshTask` handler (see `AppDelegate` in `DODApp.swift`) roughly
/// every few hours, fetches the first page of the live feed (newest posts
/// first — the same `WPRestClient.posts()` the Feed screen calls, no new
/// HTTP client), diffs the fetched ids against the last-seen id persisted in
/// `UserDefaults` via the pure ``NewPostsDiff/resolve(latestPostIDs:lastSeen:)``,
/// and schedules a notification for each newly-discovered post (newest
/// first, capped so a long-dormant install doesn't fire a barrage).
///
/// `postKind` is not knowable at the list stage — the app only classifies
/// recipe-vs-article at detail time from the post's JSON-LD (US-37) — so
/// every scheduled notification defaults to `.recipe`. `NotificationPlan`
/// only uses `postKind` for copy/deep-link host, and `dod://recipe/<id>` and
/// `dod://article/<id>` both resolve to `.openRecipe(id:)` in
/// `DeepLinkIntent.parse`, so a recipe-labeled notification for an article
/// still routes correctly on tap.
///
/// Best-effort: any network/decode failure leaves the persisted
/// `lastSeenPostID` untouched and schedules nothing, so a transient outage
/// is retried (as new posts) on the next scheduled refresh rather than
/// silently losing them.
@MainActor
final class NewPostsPoller {

    /// `UserDefaults` key for the highest WP post id this install has ever
    /// seen. `nil` (key absent) means "never polled" — the FIRST poll
    /// records a baseline without notifying (`NewPostsDiff` first-run rule),
    /// so a fresh install never gets a backlog of notifications for posts
    /// published before it existed.
    static let lastSeenPostIDKey = "dod.notifications.lastSeenPostID"

    /// Cap on how many notifications a single poll schedules, newest first.
    /// Guards against a barrage if the app has been dormant a long time and
    /// many posts published since the last successful poll.
    static let maxNotificationsPerPoll = 3

    private let restClient: WPRestClient
    private let notificationService: NotificationService
    private let defaults: UserDefaults

    init(
        restClient: WPRestClient,
        notificationService: NotificationService,
        defaults: UserDefaults = .standard
    ) {
        self.restClient = restClient
        self.notificationService = notificationService
        self.defaults = defaults
    }

    /// Fetches the latest posts, diffs against the persisted last-seen id,
    /// and schedules a notification for each newly-discovered post (newest
    /// first, capped at ``maxNotificationsPerPoll``). Best-effort: swallows
    /// any thrown error and does nothing, so a background-refresh failure
    /// never crashes the task.
    func poll() async {
        let latestPosts: [RecipeListItem]
        do {
            latestPosts = try await restClient.posts()
        } catch {
            DODLog.app.error("new-posts poll: fetch failed: \(String(describing: error))")
            return
        }

        let lastSeen = defaults.object(forKey: Self.lastSeenPostIDKey) as? Int
        let diff = NewPostsDiff.resolve(
            latestPostIDs: latestPosts.map(\.id),
            lastSeen: lastSeen
        )

        let titlesByID = Dictionary(uniqueKeysWithValues: latestPosts.map { ($0.id, $0.title) })
        for postID in diff.toNotify.prefix(Self.maxNotificationsPerPoll) {
            guard let title = titlesByID[postID] else { continue }
            await notificationService.scheduleNewPostNotification(
                title: title,
                postKind: .recipe,
                recipeID: postID
            )
        }

        if let newLastSeen = diff.newLastSeen {
            defaults.set(newLastSeen, forKey: Self.lastSeenPostIDKey)
        }
    }
}
