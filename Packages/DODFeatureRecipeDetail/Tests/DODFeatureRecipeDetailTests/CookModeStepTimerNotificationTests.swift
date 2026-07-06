import DODDomain
import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-604 — in-memory spy for ``CookStepTimerNotifying``. Records every
/// schedule / cancel so the step-timer notification tests can assert a running
/// timer scheduled its background alert and pause / reset / foreground-finish /
/// session-end cancelled it — without touching `UNUserNotificationCenter`.
@MainActor
final class FakeCookStepTimerNotifier: CookStepTimerNotifying {

    struct Scheduled: Equatable {
        let seconds: TimeInterval
        let recipeID: Int
        let stepIndex: Int
    }

    struct Cancelled: Equatable {
        let recipeID: Int
        let stepIndex: Int
    }

    private(set) var scheduled: [Scheduled] = []
    private(set) var cancelled: [Cancelled] = []
    private(set) var cancelledAll: [Int] = []

    func scheduleStepDone(after seconds: TimeInterval, recipeID: Int, stepIndex: Int) async {
        scheduled.append(Scheduled(seconds: seconds, recipeID: recipeID, stepIndex: stepIndex))
    }

    func cancelStepDone(recipeID: Int, stepIndex: Int) async {
        cancelled.append(Cancelled(recipeID: recipeID, stepIndex: stepIndex))
    }

    func cancelAllStepDone(recipeID: Int) async {
        cancelledAll.append(recipeID)
    }
}

/// DUT-604 — a Cook Mode step timer now schedules a local notification at its
/// deadline so a BACKGROUNDED timer still alerts (the in-app buzzer only fires
/// on the foreground tick loop). These pin the schedule-on-start /
/// cancel-on-pause / cancel-on-reset / cancel-on-foreground-finish /
/// cancel-all-on-session-end contract through the injected notifier spy.
///
/// The view model fires the notifier fire-and-forget (`Task { await … }`), so
/// each test yields the main actor after the mutating call to let the detached
/// task run before asserting on the spy.
@MainActor
@Suite("Cook Mode step-timer notifications (DUT-604)")
struct CookModeStepTimerNotificationTests {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    /// Draining the fire-and-forget notifier `Task`s: yield a few times so the
    /// scheduled child tasks run before we assert on the spy.
    private func drain() async {
        for _ in 0..<5 { await Task.yield() }
    }

    @Test func startingATimerSchedulesTheBackgroundAlert() async {
        let notifier = FakeCookStepTimerNotifier()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 2, stepTimerNotifier: notifier)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 120, now: t0)
        await drain()

        #expect(notifier.scheduled.count == 1)
        #expect(notifier.scheduled.first?.seconds == 120)
        #expect(notifier.scheduled.first?.stepIndex == 0)
        #expect(notifier.scheduled.first?.recipeID == vm.recipe.id)
    }

    @Test func pausingATimerCancelsItsPendingAlert() async {
        let notifier = FakeCookStepTimerNotifier()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1, stepTimerNotifier: notifier)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        vm.pauseTimer(forStep: 0, now: t0.addingTimeInterval(40))
        await drain()

        #expect(notifier.cancelled.contains { $0.stepIndex == 0 && $0.recipeID == vm.recipe.id })
    }

    @Test func resumingReschedulesFromTheRemainingTime() async {
        let notifier = FakeCookStepTimerNotifier()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1, stepTimerNotifier: notifier)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        vm.pauseTimer(forStep: 0, now: t0.addingTimeInterval(40))  // 60 left
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0.addingTimeInterval(500))
        await drain()

        // Two schedules: the initial 100s and the resume from the frozen 60s.
        #expect(notifier.scheduled.map(\.seconds) == [100, 60])
    }

    @Test func resettingATimerCancelsItsPendingAlert() async {
        let notifier = FakeCookStepTimerNotifier()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1, stepTimerNotifier: notifier)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        vm.resetTimer(forStep: 0, now: t0.addingTimeInterval(10))
        await drain()

        #expect(notifier.cancelled.contains { $0.stepIndex == 0 })
    }

    @Test func foregroundCompletionCancelsTheRedundantBanner() async {
        let notifier = FakeCookStepTimerNotifier()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 1, stepTimerNotifier: notifier)

        vm.startOrResumeTimer(forStep: 0, totalSeconds: 5, now: t0)
        vm.tickTimers(now: t0.addingTimeInterval(6))  // completes in the foreground
        await drain()

        // The in-app buzzer covers a foreground finish, so the pending system
        // banner is cancelled to avoid a redundant alert.
        #expect(notifier.cancelled.contains { $0.stepIndex == 0 })
    }

    @Test func endingCookModeCancelsEveryPendingStepAlert() async {
        let notifier = FakeCookStepTimerNotifier()
        let vm = CookModeViewModelTests.makeViewModel(stepCount: 3, stepTimerNotifier: notifier)

        vm.beginCookMode()
        vm.startOrResumeTimer(forStep: 0, totalSeconds: 100, now: t0)
        vm.startOrResumeTimer(forStep: 1, totalSeconds: 200, now: t0)
        vm.endCookMode()
        await drain()

        #expect(notifier.cancelledAll.contains(vm.recipe.id))
    }
}
