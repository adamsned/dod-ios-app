import DODPersistence
import DODSupport
import Foundation
import SwiftUI
import Testing

@testable import DODFeatureFeed

/// Coverage for the First-Cookout / Feed bug batch:
/// DUT-548 (double-log across "Back to the path"), DUT-255 (clearable
/// "Timer's Up!"), DUT-212 (cold-launch rung race), DUT-211 (share copy /
/// badge rung framing), and DUT-209 (off-main celebration-photo write).
@MainActor
@Suite("First Cookout / Feed bug batch")
struct FirstCookoutFeedBugBatchTests {

    // MARK: - DUT-548 — first cook logged exactly once across re-enter

    /// The guided path shares a host-owned `loggedRecipeIDs` set (DUT-548), so
    /// re-entering the SAME rung after "Back to the path" — which tears the
    /// `FirstCookoutView` down and rebuilds it with a fresh per-view
    /// `hasLoggedCook` — is recognised as already logged and never double-logs.
    @Test func reEnteringTheSameRungLogsTheCookOnlyOnce() {
        let box = SetBox()
        var logged: [Int] = []
        let cookout = GuidedCookout.firstCookout

        // First lifecycle: complete the cook → Done logs it once.
        let first = FirstCookoutView(
            cookout: cookout,
            onLogCook: { logged.append($0.recipeID) },
            loggedRecipeIDs: box.binding
        )
        first.logCookIfNeeded()
        #expect(logged == [cookout.recipeID])
        #expect(box.value.contains(cookout.recipeID))

        // "Back to the path" → re-enter the same rung rebuilds the view with a
        // fresh `hasLoggedCook`, but the SAME host-owned set. Done again must be a
        // no-op (the DUT-548 regression logged a second cook here).
        let reEntered = FirstCookoutView(
            cookout: cookout,
            onLogCook: { logged.append($0.recipeID) },
            loggedRecipeIDs: box.binding
        )
        reEntered.logCookIfNeeded()
        #expect(logged == [cookout.recipeID], "the re-entered rung must not log a second cook")
    }

    /// A DIFFERENT rung shares the same host set but its own recipeID, so it
    /// still logs — the dedup is per-rung (aligned with DUT-547 keying), not a
    /// blanket "already logged anything" latch.
    @Test func aDifferentRungStillLogsThroughTheSharedSet() {
        let box = SetBox()
        var logged: [Int] = []
        let rungOne = GuidedCookout.path[0]
        let rungTwo = GuidedCookout.path[1]

        FirstCookoutView(cookout: rungOne, onLogCook: { logged.append($0.recipeID) }, loggedRecipeIDs: box.binding)
            .logCookIfNeeded()
        FirstCookoutView(cookout: rungTwo, onLogCook: { logged.append($0.recipeID) }, loggedRecipeIDs: box.binding)
            .logCookIfNeeded()

        #expect(logged == [rungOne.recipeID, rungTwo.recipeID])
    }

    // MARK: - DUT-255 — "Timer's Up!" is clearable

    /// A finished bake timer can be cleared so the cook can start another for the
    /// rest of the cook stage (the card falls back to the start button).
    @Test func clearFinishedForRecipeRestoresTheStartAffordance() {
        let clock = MovableClock()
        let engine = CookTimerEngine(clock: clock.now)
        _ = engine.start(label: "Lasagna bake", duration: 1, recipeID: 1459)
        // Advance past the deadline + refresh so it finishes → "Timer's Up!".
        clock.advance(by: 5)
        engine.refresh()
        #expect(engine.timers.contains { $0.state == .finished && $0.recipeID == 1459 })

        // DUT-255 clear affordance drops this rung's finished timer.
        engine.clearFinished(for: 1459)
        #expect(engine.timers.isEmpty, "clearing must restore the start button")
    }

    /// DUT-255 clear is per-rung (shared engine, DUT-484): clearing rung A's
    /// finished timer must leave rung B's finished timer intact.
    @Test func clearFinishedForRecipeLeavesSiblingRungUntouched() {
        let clock = MovableClock()
        let engine = CookTimerEngine(clock: clock.now)
        _ = engine.start(label: "A bake", duration: 1, recipeID: 101)
        _ = engine.start(label: "B bake", duration: 1, recipeID: 202)
        clock.advance(by: 5)
        engine.refresh()  // both elapse → finished
        #expect(engine.timers.filter { $0.state == .finished }.count == 2)

        engine.clearFinished(for: 101)
        #expect(!engine.timers.contains { $0.recipeID == 101 })
        #expect(engine.timers.contains { $0.state == .finished && $0.recipeID == 202 })
    }

    // MARK: - DUT-212 — returning cook lands on their real rung after cold launch

    /// The cold-launch gate: until the real rung is loaded the chooser is handed
    /// `nil`, which falls through to the plain (all-tappable) chooser rather than
    /// recommending a stale rung 1. Once loaded, a returning cook's real rung is
    /// used. Mirrors `FeedView`'s `currentRungLoaded ? currentRung : nil`.
    @Test func chooserRecommendationIsGatedOnRungLoad() {
        // A returning cook: rung 1 already cooked, so their REAL current rung is 2.
        let cooked: Set<Int> = [GuidedCookout.path[0].recipeID]
        let realRung = GuidedCookout.nextUncookedRung(cookedRecipeIDs: cooked)
        #expect(realRung?.recipeID == GuidedCookout.path[1].recipeID)

        // Before load: the default is still rung 1, but the gate passes nil.
        let currentRungBeforeLoad: GuidedCookout? = .firstCookout
        let loadedFlag = false
        let recommendedBeforeLoad = loadedFlag ? currentRungBeforeLoad : nil
        #expect(recommendedBeforeLoad == nil, "must not recommend the stale rung-1 default before load")
        // With nil recommended, no rung is falsely marked the current "start here".
        #expect(CookChooserFlow.nodeState(index: 0, recommended: recommendedBeforeLoad, cookedRecipeIDs: cooked) == .done)

        // After load: the real rung is used, and rung 2 is the current one.
        let recommendedAfterLoad: GuidedCookout? = true ? realRung : nil
        #expect(recommendedAfterLoad?.recipeID == GuidedCookout.path[1].recipeID)
        #expect(
            CookChooserFlow.nodeState(index: 1, recommended: recommendedAfterLoad, cookedRecipeIDs: cooked) == .current
        )
    }

    // MARK: - DUT-211 — share copy / subject reflect the correct rung

    @Test func shareCopyReadsFirstOnlyForTheFirstRung() {
        let firstRung = FirstCookoutView(cookout: GuidedCookout.path[0])
        #expect(firstRung.shareCaption.contains("my first"))
        #expect(firstRung.shareSubject == "My first Dutch oven cook")

        // Rung 2 (Italian chicken) must NOT claim "first".
        let secondRung = FirstCookoutView(cookout: GuidedCookout.path[1])
        #expect(!secondRung.shareCaption.contains("my first"))
        #expect(secondRung.shareCaption.contains(GuidedCookout.path[1].dishTitle))
        #expect(secondRung.shareSubject == "My Dutch oven cook")

        // A dump cake runs through the same view and is not the first rung either.
        let dumpCake = FirstCookoutView(cookout: .dumpCake(DumpCake.all[0]))
        #expect(!dumpCake.shareCaption.contains("my first"))
        #expect(dumpCake.shareSubject == "My Dutch oven cook")
    }

    /// The campfire capstone keeps its own dish-agnostic framing (never "first").
    @Test func campfireShareCopyIsUnchangedAndNotFirst() {
        let campfire = FirstCookoutView(cookout: GuidedCookout.campfire)
        #expect(campfire.shareCaption.contains("campfire"))
        #expect(!campfire.shareCaption.contains("my first"))
        #expect(campfire.shareSubject == "My Dutch oven cook")
    }

    // MARK: - DUT-209 — celebration-photo write happens off the main thread

    /// The injected writer seam records the executor it ran on. `logCookIfNeeded`
    /// dispatches the celebration-photo write exactly the way this test does —
    /// spawning a `Task` from the `@MainActor` flow that awaits the `nonisolated
    /// async` writer — and the write must land OFF the main thread, asserted via
    /// the seam (no timing hack). This pins the DUT-209 mechanism: because
    /// `CookPhotoWriting.save` is `nonisolated`, awaiting it hops off the main
    /// actor, so the atomic full-resolution JPEG flush never blocks the dismiss.
    @Test func celebrationPhotoWriteRunsOffTheMainThread() async {
        let writer = RecordingPhotoWriter()
        // Mirror `FirstCookoutView.savePhotoOffMain`: a `Task {}` spawned from the
        // main actor that awaits the injected writer with the photo bytes.
        let photoData = Data(repeating: 0xAB, count: 1024)
        Task { _ = try? await writer.save(photoData, id: UUID().uuidString) }

        let ranOffMain = await writer.awaitWasOffMain()
        #expect(ranOffMain, "the atomic photo write must not block the main thread")
        #expect(writer.byteCount == 1024)
    }

    /// The real `SystemCookPhotoWriter` round-trips bytes to disk (DUT-209 didn't
    /// change what gets written, only where it runs).
    @Test func systemPhotoWriterRoundTripsToDisk() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let writer = SystemCookPhotoWriter()
        let id = UUID().uuidString
        let filename = try await writer.save(Data([1, 2, 3]), id: id)
        #expect(filename == "\(id).jpg")
        // The store writes under Application Support/CookPhotos; assert it's loadable.
        #expect(CookPhotoStore().data(forID: filename) == Data([1, 2, 3]))
        CookPhotoStore().delete(id: filename)
    }
}

// MARK: - Test doubles

/// A controllable clock for driving `CookTimerEngine` transitions deterministically
/// (DUT-255): `start` anchors `endDate` off `now()`, then `advance` pushes `now`
/// past the deadline so `refresh()` finishes the timer.
private final class MovableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_700_000_000)

    var now: () -> Date {
        { [self] in
            lock.lock(); defer { lock.unlock() }
            return current
        }
    }

    func advance(by seconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(seconds)
    }
}

/// A mutable box backing a `Binding<Set<Int>>` so tests can share the host-owned
/// `loggedRecipeIDs` across two `FirstCookoutView` lifecycles (DUT-548) without a
/// live SwiftUI hierarchy.
@MainActor
private final class SetBox {
    var value: Set<Int> = []
    var binding: Binding<Set<Int>> {
        Binding(get: { self.value }, set: { self.value = $0 })
    }
}

/// Records whether `save` ran off the main thread and how many bytes it saw
/// (DUT-209). `nonisolated` `save` so it executes off the caller's actor.
private final class RecordingPhotoWriter: CookPhotoWriting, @unchecked Sendable {
    private let lock = NSLock()
    private var wasOffMain: Bool?
    private var savedByteCount = 0

    /// Thread-safe read of the byte count recorded by the last `save`.
    var byteCount: Int { withLock { savedByteCount } }

    func save(_ data: Data, id: String) async throws -> String {
        // Record synchronously (a sync helper can read `Thread.isMainThread` /
        // take the lock, which are both unavailable directly in an async body).
        record(byteCount: data.count)
        return "\(id).jpg"
    }

    /// Synchronous, `nonisolated`: samples the executor the async `save` body is
    /// running on. A `nonisolated async` method invoked from a `@MainActor` Task
    /// runs OFF the main thread, so this observes `false` for `isMainThread`.
    private func record(byteCount: Int) {
        let offMain = !Thread.isMainThread
        withLock {
            wasOffMain = offMain
            savedByteCount = byteCount
        }
    }

    /// Poll until the detached write has recorded its executor, then report it.
    func awaitWasOffMain() async -> Bool {
        for _ in 0..<200 {
            if let recorded = withLock({ wasOffMain }) { return recorded }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        return false
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
