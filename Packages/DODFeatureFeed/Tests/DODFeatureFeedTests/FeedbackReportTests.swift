import Testing

@testable import DODFeatureFeed

@Suite struct FeedbackReportTests {
    @Test func emptyOrWhitespaceTextIsNotSubmittable() {
        let report = FeedbackReport(category: .bug, text: "  \n")
        #expect(report.isSubmittable == false)
        #expect(report.mailtoURL == nil)
    }

    @Test func mailtoTargetsTheTeamWithSubjectAndBody() {
        let report = FeedbackReport(category: .idea, text: "Add timers")
        guard let url = report.mailtoURL else {
            #expect(false, "mailtoURL should not be nil")
            return
        }
        #expect(url.scheme == "mailto")
        #expect(url.absoluteString.hasPrefix("mailto:ned@dutchovendaddy.com"))
        #expect(url.absoluteString.contains("Idea"))
    }

    @Test func diagnosticsOnlyAppearWhenProvided() {
        // Without diagnostics
        let report1 = FeedbackReport(category: .bug, text: "Add timers")
        #expect(report1.body == "Add timers")

        // With diagnostics
        let diagnostics = FeedbackDiagnostics(
            appVersion: "1.0",
            osVersion: "26.0",
            deviceModel: "iPhone",
            currentScreen: "feed"
        )
        let report2 = FeedbackReport(category: .bug, text: "Add timers", diagnostics: diagnostics)
        #expect(report2.body.contains("App version: 1.0"))
        #expect(report2.body.contains("Screen: feed"))
    }
}
