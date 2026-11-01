import DODFeatureFeed
import DODSupport
import Foundation
import Testing

@testable import DODApp

@MainActor
@Suite struct StreakNudgeNotifierTests {
    @Test func requestCarriesDeepLinkAndCopy() throws {
        let content = try #require(StreakNudge.content(for: .atRisk(streak: 3)))
        let request = StreakNudgeNotifier.makeRequest(content: content, fireIn: 60)
        #expect(request.identifier == "dod.streakNudge")
        #expect(request.content.userInfo[NotificationPlan.deepLinkKey] as? String == "dod://feed")
        #expect(request.content.title == content.title)
    }

    @Test func disabledToggleSchedulesNothing() async throws {
        let defaults = try #require(UserDefaults(suiteName: "streak-test-\(UUID())"))
        let notifier = StreakNudgeNotifier(defaults: defaults)
        let scheduled = await notifier.evaluateAndSchedule(entries: [])
        #expect(scheduled == false)
    }
}
