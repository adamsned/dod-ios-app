import DODSupport
import Foundation
import Testing

@testable import DODFeatureFeed

/// DUT-297 — the guided First Cookout bake timer schedules a local notification
/// at the deadline so "you can step away" holds when the app is backgrounded
/// (the foreground tick loop can't finish the timer in the background).
///
/// DUT-547 — the guided path shares ONE `CookTimerEngine` across every rung
/// (DUT-484), so two rungs' bakes can be pending at once. These pin the notifier
/// seam and the per-recipe identifier scheme; the view-level start→schedule /
/// finish→cancel wiring is build- + device-verified.
@Suite("First Cookout bake notifier (DUT-297 / DUT-547)")
struct FirstCookoutBakeNotifierTests {

    @Test func nonPositiveDurationsScheduleNothing() async {
        // The guard returns before touching UNUserNotificationCenter — a 0 /
        // negative bake duration is a no-op, never a crash or a fire-now alert.
        let notifier = SystemBakeTimerNotifier()
        await notifier.scheduleBakeDone(after: 0, recipeID: 101)
        await notifier.scheduleBakeDone(after: -30, recipeID: 101)
    }

    @Test func copyAndBaseIdentifierAreWired() {
        #expect(!SystemBakeTimerNotifier.title.isEmpty)
        #expect(!SystemBakeTimerNotifier.body.isEmpty)
        // Stable base id; a nil recipe falls back to it (the single-timer path).
        #expect(SystemBakeTimerNotifier.identifier == "dod.firstCookout.bakeDone")
        #expect(SystemBakeTimerNotifier.identifier(for: nil) == "dod.firstCookout.bakeDone")
    }

    // DUT-547 — two different recipeIDs must derive two DISTINCT identifiers, so
    // scheduling rung B's bake can't replace rung A's still-pending request.
    @Test func distinctRecipesDeriveDistinctIdentifiers() {
        let idA = SystemBakeTimerNotifier.identifier(for: 101)
        let idB = SystemBakeTimerNotifier.identifier(for: 202)
        #expect(idA == "dod.firstCookout.bakeDone.101")
        #expect(idB == "dod.firstCookout.bakeDone.202")
        #expect(idA != idB)
        // Both are recognised as bake-done ids (for the opt-out flush filter).
        #expect(SystemBakeTimerNotifier.isBakeDoneIdentifier(idA))
        #expect(SystemBakeTimerNotifier.isBakeDoneIdentifier(idB))
        #expect(SystemBakeTimerNotifier.isBakeDoneIdentifier("dod.firstCookout.bakeDone"))
        #expect(!SystemBakeTimerNotifier.isBakeDoneIdentifier("dod.somethingElse"))
    }

    @Test func schedulingBDoesNotReplaceA() async {
        // A per-recipe fake models the real `UNUserNotificationCenter` keyed
        // store: scheduling B leaves A's pending request intact (the DUT-547
        // regression — a single shared id would have B overwrite A).
        let fake = FakeBakeTimerNotifier()
        await fake.scheduleBakeDone(after: 1800, recipeID: 101)
        await fake.scheduleBakeDone(after: 1200, recipeID: 202)
        #expect(fake.pending[101] == 1800)
        #expect(fake.pending[202] == 1200)
    }

    @Test func cancelForARemovesOnlyA() async {
        let fake = FakeBakeTimerNotifier()
        await fake.scheduleBakeDone(after: 1800, recipeID: 101)
        await fake.scheduleBakeDone(after: 1200, recipeID: 202)
        await fake.cancelBakeDone(for: 101)
        #expect(fake.pending[101] == nil)  // A's alert gone…
        #expect(fake.pending[202] == 1200)  // …B's still pending.
    }

    @Test func cancelAllFlushesEveryRecipe() async {
        // DUT-379 opt-out flush drops every queued bake alert, all recipes.
        let fake = FakeBakeTimerNotifier()
        await fake.scheduleBakeDone(after: 1800, recipeID: 101)
        await fake.scheduleBakeDone(after: 1200, recipeID: 202)
        await fake.scheduleBakeDone(after: 600, recipeID: nil)
        await fake.cancelAllBakeDone()
        #expect(fake.pending.isEmpty)
    }

    // DUT-547 — the `onFinished` wiring: when timer A finishes, the view cancels
    // A's per-recipe alert via `timer.recipeID`, never a sibling rung B's. This
    // exercises the exact closure `FirstCookoutView` installs on the engine.
    @Test func onFinishedCancelsOnlyTheFinishedTimersRecipe() async {
        let fake = FakeBakeTimerNotifier()
        await fake.scheduleBakeDone(after: 1800, recipeID: 101)
        await fake.scheduleBakeDone(after: 1200, recipeID: 202)

        // Mirror FirstCookoutView.body's `.task` closure (a finished CookTimer in,
        // cancel that timer's own recipe out).
        let onFinished: (CookTimer) -> Void = { timer in
            Task { await fake.cancelBakeDone(for: timer.recipeID) }
        }
        let finishedA = CookTimer(
            id: UUID(),
            label: "Rung A bake",
            duration: 1800,
            state: .finished,
            recipeID: 101
        )
        onFinished(finishedA)
        // The cancel runs on a detached Task, so poll the observable outcome
        // (A's slot cleared) up to a bounded deadline instead of guessing at a
        // fixed wall-clock sleep — deterministic on a slow/loaded CI box.
        await waitUntil { fake.pending[101] == nil }

        #expect(fake.pending[101] == nil)  // A's alert cancelled…
        #expect(fake.pending[202] == 1200)  // …B (still on screen) untouched.
    }

    /// Poll until `condition` holds or a short deadline passes — replaces a
    /// fixed sleep waiting on a detached Task (DUT-700 test hardening). Mirrors
    /// `SavedRecipesWidgetPublisherTests.waitUntil`.
    private func waitUntil(_ condition: @Sendable () -> Bool, timeout: TimeInterval = 2.0) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}

/// Per-recipe fake modelling the keyed `UNUserNotificationCenter` store: one
/// pending duration per recipeID (nil → a sentinel key), so a schedule for a new
/// recipe adds a request rather than replacing a different one.
private final class FakeBakeTimerNotifier: BakeTimerNotifying, @unchecked Sendable {
    /// recipeID → scheduled seconds. `nil` recipe uses the sentinel key.
    private(set) var pending: [Int: TimeInterval] = [:]
    private static let nilKey = Int.min

    private func key(_ recipeID: Int?) -> Int { recipeID ?? Self.nilKey }

    func scheduleBakeDone(after seconds: TimeInterval, recipeID: Int?) async {
        guard seconds > 0 else { return }
        pending[key(recipeID)] = seconds
    }

    func cancelBakeDone(for recipeID: Int?) async {
        pending[key(recipeID)] = nil
    }

    func cancelAllBakeDone() async {
        pending.removeAll()
    }
}
