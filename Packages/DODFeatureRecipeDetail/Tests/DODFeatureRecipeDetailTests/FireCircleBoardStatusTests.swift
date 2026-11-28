import DODSupport
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

@Suite("FireCircleBoardView status")
struct FireCircleBoardStatusTests {
    private let now = Date(timeIntervalSince1970: 1_000)

    private func cook(paused: Bool, completed: Bool, endsIn: Double?) -> FireCircleCook {
        FireCircleCook(
            peerID: "peer",
            cookName: "Ned",
            recipeTitle: "Ribs",
            stepText: "Smoke",
            remainingSeconds: 90,
            endDate: endsIn.map { now.addingTimeInterval($0) },
            isPaused: paused,
            isCompleted: completed,
            sentAt: now
        )
    }

    @Test func completedShowsDone() {
        let done = cook(paused: false, completed: true, endsIn: nil)
        #expect(FireCircleBoardView.status(for: done, now: now) == "Done")
    }

    @Test func pausedShowsPaused() {
        let held = cook(paused: true, completed: false, endsIn: nil)
        #expect(FireCircleBoardView.status(for: held, now: now) == "Paused")
    }

    @Test func runningShowsClock() {
        let live = cook(paused: false, completed: false, endsIn: 65)
        #expect(FireCircleBoardView.status(for: live, now: now) == "1:05")
    }
}
