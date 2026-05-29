import DODDomain
import Foundation
import Testing

@testable import DODFeatureFeed

/// L1 unit coverage for the local-notification content builder + the
/// suppression gate (spec US-42 / AC-42.2, AC-42.3, AC-42.4, AC-42.6).
///
/// These exercise the pure logic only — the `UNUserNotificationCenter`
/// scheduling wrapper lives in the app target and is verified by the
/// build + the manual simulator test (the test affordance), not here.
@Suite("NotificationContentBuilder (T-631 / US-42)") struct NotificationContentTests {

    // MARK: - AC-42.2 — type-aware copy

    @Test func recipePlanUsesRecipeCopy() {
        let plan = NotificationContentBuilder.plan(
            postTitle: "Cast Iron Burgers (Easy Skillet Recipe)",
            postKind: .recipe,
            postID: 1234
        )
        #expect(plan.title == "New Recipe 🍳")
        #expect(plan.body == "Cast Iron Burgers (Easy Skillet Recipe) just dropped — tap to start cooking.")
    }

    @Test func articlePlanUsesArticleCopy() {
        let plan = NotificationContentBuilder.plan(
            postTitle: "Best Dutch Oven Recipes (30+ Tried and Tested Favorites)",
            postKind: .article,
            postID: 5678
        )
        #expect(plan.title == "New Article 📖")
        #expect(plan.body == "Best Dutch Oven Recipes (30+ Tried and Tested Favorites) is up — tap to read.")
    }

    @Test func postTitleIsInterpolatedVerbatim() {
        // The title is interpolated as-is; no truncation / escaping.
        let plan = NotificationContentBuilder.plan(
            postTitle: "Title with — em dash & ampersand",
            postKind: .recipe,
            postID: 1
        )
        #expect(plan.body.contains("Title with — em dash & ampersand"))
    }

    // MARK: - AC-42.3 / AC-42.6 — userInfo deep-link payload shape

    @Test func recipePlanCarriesRecipeDeepLink() {
        let plan = NotificationContentBuilder.plan(
            postTitle: "Cast Iron Burgers",
            postKind: .recipe,
            postID: 1234
        )
        #expect(plan.userInfo[NotificationPlan.deepLinkKey] == "dod://recipe/1234")
        #expect(plan.deepLink == "dod://recipe/1234")
    }

    @Test func articlePlanCarriesArticleDeepLink() {
        let plan = NotificationContentBuilder.plan(
            postTitle: "Best Dutch Oven Recipes",
            postKind: .article,
            postID: 5678
        )
        #expect(plan.userInfo[NotificationPlan.deepLinkKey] == "dod://article/5678")
        #expect(plan.deepLink == "dod://article/5678")
    }

    @Test func deepLinkKeyIsStableWireFormat() {
        // The app-target delegate reads this exact key — pin it so a rename
        // can't silently break tap routing.
        #expect(NotificationPlan.deepLinkKey == "dod.deeplink")
    }

    // MARK: - AC-42.4 — toggle-off suppression (single gate)

    @Test func suppressionGateRequiresBothToggleAndAuthorization() {
        // Only on + authorized may schedule; every other combination is
        // suppressed (off ⇒ silence, with no leak).
        #expect(NotificationContentBuilder.shouldSchedule(toggleEnabled: true, systemAuthorized: true) == true)
        #expect(NotificationContentBuilder.shouldSchedule(toggleEnabled: true, systemAuthorized: false) == false)
        #expect(NotificationContentBuilder.shouldSchedule(toggleEnabled: false, systemAuthorized: true) == false)
        #expect(NotificationContentBuilder.shouldSchedule(toggleEnabled: false, systemAuthorized: false) == false)
    }
}
