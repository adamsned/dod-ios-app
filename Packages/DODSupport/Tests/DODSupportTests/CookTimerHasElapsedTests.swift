import Foundation
import Testing

@testable import DODSupport

final class CookTimerHasElapsedTests {
    @Test func running_timer_now_less_than_endDate_expect_hasElapsed_false() {
        let baseDate = Date(timeIntervalSince1970: 1000)
        let timer = CookTimer(
            id: UUID(),
            label: "Bake",
            duration: 600,
            state: .running(endDate: baseDate.addingTimeInterval(60)),
            recipeID: nil
        )
        let now = baseDate.addingTimeInterval(30)

        #expect(timer.hasElapsed(at: now) == false)
    }

    @Test func running_timer_now_equal_to_endDate_expect_hasElapsed_true() {
        let baseDate = Date(timeIntervalSince1970: 1000)
        let timer = CookTimer(
            id: UUID(),
            label: "Bake",
            duration: 600,
            state: .running(endDate: baseDate.addingTimeInterval(60)),
            recipeID: nil
        )
        let now = baseDate.addingTimeInterval(60)

        #expect(timer.hasElapsed(at: now) == true)
    }

    @Test func running_timer_now_greater_than_endDate_expect_hasElapsed_true() {
        let baseDate = Date(timeIntervalSince1970: 1000)
        let timer = CookTimer(
            id: UUID(),
            label: "Bake",
            duration: 600,
            state: .running(endDate: baseDate.addingTimeInterval(60)),
            recipeID: nil
        )
        let now = baseDate.addingTimeInterval(90)

        #expect(timer.hasElapsed(at: now) == true)
    }

    @Test func paused_timer_expect_hasElapsed_false() {
        let timer = CookTimer(id: UUID(), label: "Bake", duration: 600, state: .paused(remaining: 30), recipeID: nil)

        #expect(timer.hasElapsed(at: Date(timeIntervalSince1970: 2000)) == false)
    }

    @Test func finished_timer_expect_hasElapsed_true() {
        let timer = CookTimer(id: UUID(), label: "Bake", duration: 600, state: .finished, recipeID: nil)

        #expect(timer.hasElapsed(at: Date(timeIntervalSince1970: 3000)) == true)
    }

    @Test func paused_timer_with_now_far_in_future_expect_hasElapsed_false() {
        let timer = CookTimer(id: UUID(), label: "Bake", duration: 600, state: .paused(remaining: 15), recipeID: nil)

        #expect(timer.hasElapsed(at: Date(timeIntervalSince1970: 1_000_000)) == false, "paused freezes elapsed")
    }
}
