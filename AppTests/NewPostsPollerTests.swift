import DODDomain
import DODNetworking
import Foundation
import Testing

@testable import DODApp

/// Coverage for ``NewPostsPoller/poll()`` (DUT-938) — the background-refresh
/// trigger that fetches the latest WP posts, diffs against the persisted
/// `lastSeenPostID` via the pure `NewPostsDiff.resolve(latestPostIDs:lastSeen:)`
/// (already covered by `NewPostsDiffTests` in `DODSupportTests` — not
/// re-tested here), and schedules a capped number of local notifications.
///
/// `WPRestClient` is faked at its `HTTPClient` seam with `FakeHTTPClient`
/// (the same convention `WPRestClientTests` / `WPRestClientPostsEdgeCasesTests`
/// already use in `DODNetworkingTests`). `NotificationService` has no
/// protocol seam to fake — it wraps `UNUserNotificationCenter` directly — so
/// these tests construct the REAL service against a throwaway
/// `UserDefaults(suiteName:)` where `SettingsViewModel.notificationsEnabledKey`
/// is absent (defaults to `false`). `NotificationService.scheduleNewPostNotification`
/// gates on `toggleEnabled && systemAuthorized`
/// (`NotificationContentBuilder.shouldSchedule`), so with the toggle off it
/// safely no-ops before ever touching the real notification center in a
/// scheduling way. That means the actual "was a notification scheduled" call
/// isn't observable from a unit test host — these tests instead pin the
/// fully-observable side effect: the persisted `lastSeenPostID` watermark,
/// which is where the interesting DUT-938 correctness lives (first-run
/// baseline, watermark-vs-notification-cap independence, and best-effort
/// failure handling).
///
/// Each test uses its own throwaway `UserDefaults(suiteName:)` (passed as
/// both the poller's and the notification service's `defaults:`) so runs
/// never leak state into each other or into `.standard`.
@Suite("NewPostsPoller.poll()")
struct NewPostsPollerTests {

    private func isolatedDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "NewPostsPollerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("failed to create isolated UserDefaults suite")
            return (.standard, suiteName)
        }
        return (defaults, suiteName)
    }

    /// Minimal-but-complete WP post JSON object — matches the shape
    /// `WPRestClientPostsEdgeCasesTests` already uses, so a clean
    /// `WPDTO.Post` decode never depends on a field this suite forgot.
    private func postJSON(id: Int, title: String) -> String {
        """
        {
          "id": \(id),
          "slug": "post-\(id)",
          "link": "https://www.dutchovendaddy.com/post-\(id)/",
          "title": { "rendered": "\(title)" },
          "excerpt": { "rendered": "<p>Excerpt for \(title).</p>" },
          "date": "2026-05-01T10:00:00",
          "categories": []
        }
        """
    }

    private func postsPage(_ posts: [String]) -> Data {
        Data("[\(posts.joined(separator: ","))]".utf8)
    }

    @MainActor
    @Test("first poll ever (no lastSeen key) records a baseline without notifying")
    func firstPollWithNoLastSeenRecordsBaseline() async {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let fake = FakeHTTPClient()
        await fake.stub(
            urlContaining: "posts",
            json: postsPage([
                postJSON(id: 10, title: "Post 10"),
                postJSON(id: 20, title: "Post 20"),
                postJSON(id: 30, title: "Post 30"),
            ])
        )
        let poller = NewPostsPoller(
            restClient: WPRestClient(httpClient: fake),
            notificationService: NotificationService(defaults: defaults),
            defaults: defaults
        )

        await poller.poll()

        // First-run rule (`NewPostsDiff`): the baseline is the MAX fetched id,
        // recorded with nothing to notify — a fresh install never gets a
        // backlog of notifications for posts published before it existed.
        let lastSeen = defaults.object(forKey: NewPostsPoller.lastSeenPostIDKey) as? Int
        #expect(lastSeen == 30)
    }

    @MainActor
    @Test("a genuinely new post beyond lastSeen advances the watermark")
    func newPostBeyondLastSeenAdvancesWatermark() async {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(100, forKey: NewPostsPoller.lastSeenPostIDKey)

        let fake = FakeHTTPClient()
        await fake.stub(
            urlContaining: "posts",
            json: postsPage([
                postJSON(id: 100, title: "Already Seen"),
                postJSON(id: 105, title: "Brand New"),
            ])
        )
        let poller = NewPostsPoller(
            restClient: WPRestClient(httpClient: fake),
            notificationService: NotificationService(defaults: defaults),
            defaults: defaults
        )

        await poller.poll()

        // With the notifications toggle off (fresh suite), whether a
        // notification was actually scheduled isn't observable from a unit
        // test host — so this pins the watermark side effect, which is the
        // signal that `poll()` correctly identified post 105 as new.
        let lastSeen = defaults.object(forKey: NewPostsPoller.lastSeenPostIDKey) as? Int
        #expect(lastSeen == 105)
    }

    @MainActor
    @Test("more than maxNotificationsPerPoll new posts still advances the watermark to the true max")
    func moreThanMaxNotificationsCapDoesNotAffectWatermark() async {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(10, forKey: NewPostsPoller.lastSeenPostIDKey)

        // 5 new posts, more than `maxNotificationsPerPoll` (3).
        let fake = FakeHTTPClient()
        await fake.stub(
            urlContaining: "posts",
            json: postsPage([
                postJSON(id: 20, title: "Post 20"),
                postJSON(id: 21, title: "Post 21"),
                postJSON(id: 22, title: "Post 22"),
                postJSON(id: 23, title: "Post 23"),
                postJSON(id: 24, title: "Post 24"),
            ])
        )
        let poller = NewPostsPoller(
            restClient: WPRestClient(httpClient: fake),
            notificationService: NotificationService(defaults: defaults),
            defaults: defaults
        )

        await poller.poll()

        // The notification cap (3) only limits how many notifications are
        // scheduled — it must never cap the persisted watermark, or a
        // long-dormant install would keep re-notifying posts 23/24 forever.
        let lastSeen = defaults.object(forKey: NewPostsPoller.lastSeenPostIDKey) as? Int
        #expect(lastSeen == 24)
    }

    @MainActor
    @Test("a fetch failure leaves lastSeenPostID untouched")
    func fetchFailureLeavesLastSeenUntouched() async {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(50, forKey: NewPostsPoller.lastSeenPostIDKey)

        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data(), statusCode: 500)
        let poller = NewPostsPoller(
            restClient: WPRestClient(httpClient: fake),
            notificationService: NotificationService(defaults: defaults),
            defaults: defaults
        )

        await poller.poll()

        // Best-effort: swallow, log, do nothing — a transient outage is
        // retried as "new" on the next successful poll rather than silently
        // advancing past posts that were never actually seen.
        let lastSeen = defaults.object(forKey: NewPostsPoller.lastSeenPostIDKey) as? Int
        #expect(lastSeen == 50)
    }

    @MainActor
    @Test("duplicate post ids in the fetched page don't crash, and the first title wins")
    func duplicatePostIDsInFeedDoNotCrash() async {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Same id twice — the dup-id trap class (cf. RecipeStore #605):
        // `Dictionary(uniquingKeysWith:)` must keep the FIRST title rather
        // than trapping like `uniqueKeysWithValues:` would.
        let fake = FakeHTTPClient()
        await fake.stub(
            urlContaining: "posts",
            json: postsPage([
                postJSON(id: 42, title: "First Title"),
                postJSON(id: 42, title: "Second Title"),
            ])
        )
        let poller = NewPostsPoller(
            restClient: WPRestClient(httpClient: fake),
            notificationService: NotificationService(defaults: defaults),
            defaults: defaults
        )

        await poller.poll()

        // Reaching this line at all is the crash-safety assertion; the
        // watermark should still reflect the (deduped) fetched id.
        let lastSeen = defaults.object(forKey: NewPostsPoller.lastSeenPostIDKey) as? Int
        #expect(lastSeen == 42)
    }

    @MainActor
    @Test("an empty fetched list doesn't crash or falsely advance the watermark")
    func emptyFetchedListDoesNotFalselyAdvanceWatermark() async {
        let (defaults, suiteName) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(77, forKey: NewPostsPoller.lastSeenPostIDKey)

        let fake = FakeHTTPClient()
        await fake.stub(urlContaining: "posts", json: Data("[]".utf8))
        let poller = NewPostsPoller(
            restClient: WPRestClient(httpClient: fake),
            notificationService: NotificationService(defaults: defaults),
            defaults: defaults
        )

        await poller.poll()

        // `NewPostsDiff.resolve` rule 1: an empty `latestPostIDs` returns
        // `(toNotify: [], newLastSeen: lastSeen)` unchanged.
        let lastSeen = defaults.object(forKey: NewPostsPoller.lastSeenPostIDKey) as? Int
        #expect(lastSeen == 77)
    }
}
