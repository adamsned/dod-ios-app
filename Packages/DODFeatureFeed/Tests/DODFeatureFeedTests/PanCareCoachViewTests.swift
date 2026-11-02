import SwiftUI
import Testing

@testable import DODFeatureFeed

@MainActor
@Suite("PanCareCoachView (DUT-971)") struct PanCareCoachViewTests {
    @Test func hasThreeSteps() {
        #expect(PanCareCoachView.steps.count == 3)
    }

    @Test func headlineIsNonEmpty() {
        #expect(!PanCareCoachView.headline.isEmpty)
    }

    @Test func bodyBuildsWithoutCrashing() {
        let view = PanCareCoachView(onLogCare: {}, onSkip: {})
        _ = view.body
    }
}
