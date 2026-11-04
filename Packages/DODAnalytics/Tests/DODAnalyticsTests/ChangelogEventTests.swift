import Testing

@testable import DODAnalytics

@Suite("Changelog analytics events") struct ChangelogEventTests {

    @Test func changelogEventsHaveStableNamesAndAnonymousPayloads() {
        #expect(AnalyticsEvent.changelogShown(version: "2.1").name == "changelog_shown")
        #expect(AnalyticsEvent.changelogShown(version: "2.1").payload == ["version": "2.1"])
        #expect(AnalyticsEvent.changelogDismissed(version: "2.1").name == "changelog_dismissed")
        #expect(AnalyticsEvent.changelogDismissed(version: "2.1").payload == ["version": "2.1"])
        #expect(AnalyticsEvent.changelogOpenedFromSettings.name == "changelog_opened_from_settings")
        #expect(AnalyticsEvent.changelogOpenedFromSettings.payload.isEmpty)
    }
}
