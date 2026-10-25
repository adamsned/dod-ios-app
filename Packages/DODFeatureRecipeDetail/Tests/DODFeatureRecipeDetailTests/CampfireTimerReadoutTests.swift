import Foundation
import Testing

@testable import DODFeatureRecipeDetail

struct CampfireTimerReadoutTests {
    @Test func formatsMinutesAndSeconds() {
        #expect(CampfireTimerReadout.format(seconds: 125) == "2:05")
    }
    @Test func formatsHours() {
        #expect(CampfireTimerReadout.format(seconds: 3725) == "1:02:05")
    }
    @Test func negativeClampsToZero() {
        #expect(CampfireTimerReadout.format(seconds: -5) == "0:00")
    }

    @Test func nilWhenNoTimers() {
        #expect(CampfireTimerReadout.text(timers: [:], currentStep: 0, now: Date()) == nil)
    }
    @Test func prefersCurrentStepTimer() {
        let timers = [0: CookStepTimer(totalSeconds: 90, state: .paused(remaining: 60))]
        #expect(CampfireTimerReadout.text(timers: timers, currentStep: 0, now: Date()) == "1:00")
    }
    @Test func fallsBackToSoonestRunning() {
        let now = Date()
        let timers = [
            2: CookStepTimer(totalSeconds: 60, state: .running(endDate: now.addingTimeInterval(30))),
            3: CookStepTimer(totalSeconds: 600, state: .running(endDate: now.addingTimeInterval(300))),
        ]
        #expect(CampfireTimerReadout.text(timers: timers, currentStep: 0, now: now) == "0:30")
    }
    @Test func idleCurrentStepIgnored() {
        let timers = [0: CookStepTimer(totalSeconds: 90, state: .idle)]
        #expect(CampfireTimerReadout.text(timers: timers, currentStep: 0, now: Date()) == nil)
    }
}
