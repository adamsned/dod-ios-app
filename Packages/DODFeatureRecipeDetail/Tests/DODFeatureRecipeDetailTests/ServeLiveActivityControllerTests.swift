import DODCookActivity
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite struct ServeLiveActivityControllerTests {
    private func state(isCompleted: Bool) -> ServeActivityAttributes.ContentState {
        ServeActivityAttributes.ContentState(
            dishes: [],
            serveAt: Date(timeIntervalSince1970: 1000),
            isCompleted: isCompleted
        )
    }

    @Test func staleDateIsSixtySecondsAfterServe() {
        let date = ServeLiveActivityStale.staleDate(for: state(isCompleted: false))
        #expect(date == Date(timeIntervalSince1970: 1060))
    }

    @Test func completedStateNeverGoesStale() {
        let date = ServeLiveActivityStale.staleDate(for: state(isCompleted: true))
        #expect(date == .distantFuture)
    }

    #if os(macOS)
    @MainActor
    @Test func systemControllerIsInactiveOnMacOS() {

        let controller = SystemServeLiveActivityController()
        #expect(!controller.isActive)
    }
    #endif
}
