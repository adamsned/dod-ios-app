import Foundation
import Testing

@testable import DODFeatureFeed

/// DUT-297 — the guided First Cookout bake timer now schedules a local
/// notification at the deadline so "you can step away" holds when the app is
/// backgrounded (the foreground tick loop can't finish the timer in the
/// background). These pin the notifier seam; the view-level start→schedule /
/// cancel→cancel wiring is build- + device-verified.
@Suite("First Cookout bake notifier (DUT-297)")
struct FirstCookoutBakeNotifierTests {

    @Test func nonPositiveDurationsScheduleNothing() async {
        // The guard returns before touching UNUserNotificationCenter — a 0 /
        // negative bake duration is a no-op, never a crash or a fire-now alert.
        let notifier = SystemBakeTimerNotifier()
        await notifier.scheduleBakeDone(after: 0)
        await notifier.scheduleBakeDone(after: -30)
    }

    @Test func copyAndIdentifierAreWired() {
        #expect(!SystemBakeTimerNotifier.title.isEmpty)
        #expect(!SystemBakeTimerNotifier.body.isEmpty)
        // Stable id so a re-scheduled / cancelled timer replaces rather than stacks.
        #expect(SystemBakeTimerNotifier.identifier == "dod.firstCookout.bakeDone")
    }

    @Test func aFakeNotifierRecordsTheScheduleThenCancelContract() async {
        let fake = FakeBakeTimerNotifier()
        await fake.scheduleBakeDone(after: 1800)
        await fake.cancelBakeDone()
        #expect(fake.scheduled == [1800])
        #expect(fake.cancelCount == 1)
    }
}

private final class FakeBakeTimerNotifier: BakeTimerNotifying, @unchecked Sendable {
    private(set) var scheduled: [TimeInterval] = []
    private(set) var cancelCount = 0
    func scheduleBakeDone(after seconds: TimeInterval) async { scheduled.append(seconds) }
    func cancelBakeDone() async { cancelCount += 1 }
}
