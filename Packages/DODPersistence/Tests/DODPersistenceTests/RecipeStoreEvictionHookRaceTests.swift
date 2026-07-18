import Foundation
import Testing

@testable import DODPersistence

/// `RecipeStore.onBridgedImagesEvicted` is a process-global. Before this fix it
/// was a bare `nonisolated(unsafe)` static: `evictImagesIfNeeded()` (the
/// store-actor read path) and a direct test assignment both touched it with NO
/// lock at all, while the App target's old `installBridgedEvictionHook` took
/// its OWN separate `NSLock` around just the install's check-then-set. Two
/// independently-guarded (or unguarded) access paths on the same shared
/// mutable state is a genuine data race — `AppTests/EvictionHookInstallTests`'s
/// own DUT-475 comment says as much: "the store-actor read of the still-nil
/// `nonisolated(unsafe)` hook races the write." DUT-475 only narrowed the
/// timing window (installing earlier in the app lifecycle); it never actually
/// synchronized the two sides.
///
/// The fix moves the lock next to the storage in `DODPersistence` itself and
/// routes every read, every write, AND the idempotent install's check-then-set
/// through that ONE lock (``RecipeStore/installEvictionHookIfNeeded(_:)``).
/// `.serialized` because the static is process-global — parallel tests here
/// would race each other over the very state under test.
@Suite("RecipeStore eviction hook install race (nonisolated(unsafe) hardening)", .serialized)
struct RecipeStoreEvictionHookRaceTests {

    init() {
        RecipeStore.onBridgedImagesEvicted = nil
    }

    /// A regressed version of this fix (two separately-locked or unlocked
    /// check-then-set operations) can let more than one concurrent installer
    /// win. Firing many installers at once from REAL OS threads
    /// (`DispatchQueue.concurrentPerform`, not cooperative-pool `Task`s) and
    /// requiring exactly one `true` is the deterministic signal that the
    /// compare-and-set is genuinely atomic under the shared lock.
    @Test func installEvictionHookIfNeededIsAtomicUnderConcurrentInstallers() {
        RecipeStore.onBridgedImagesEvicted = nil
        let winners = Counter()
        let iterations = 200

        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            let installed = RecipeStore.installEvictionHookIfNeeded {
                winners.recordWinner(index)
            }
            if installed { winners.recordInstall() }
        }

        #expect(
            winners.installCount == 1,
            "exactly one concurrent installer must win the idempotent latch"
        )
        #expect(RecipeStore.onBridgedImagesEvicted != nil)
    }

    /// Once installed, the hook must be exactly the FIRST winner's closure —
    /// not silently overwritten by a later racing installer, and not dropped.
    @Test func installedHookIsTheFirstWinnersClosure() {
        RecipeStore.onBridgedImagesEvicted = nil
        let winners = Counter()

        DispatchQueue.concurrentPerform(iterations: 100) { index in
            let installed = RecipeStore.installEvictionHookIfNeeded {
                winners.recordWinner(index)
            }
            if installed { winners.recordInstall() }
        }

        RecipeStore.onBridgedImagesEvicted?()
        #expect(winners.installCount == 1)
        #expect(winners.invocationCount == 1, "the installed hook must fire exactly once when invoked")
    }

    /// Concurrent reads (the store-actor's `evictImagesIfNeeded()` shape —
    /// fetch the closure, then call it) interleaved with the install must
    /// never crash and must always observe either `nil` or the fully-formed
    /// closure — never a torn/partial reference. Real threads, not `Task`s, so
    /// this actually exercises the lock rather than Swift's cooperative pool.
    @Test func concurrentReadsDuringInstallNeverCrash() {
        RecipeStore.onBridgedImagesEvicted = nil
        let readCount = Counter()

        DispatchQueue.concurrentPerform(iterations: 300) { index in
            if index == 150 {
                RecipeStore.installEvictionHookIfNeeded { readCount.recordWinner(index) }
            } else {
                // Mirrors `evictImagesIfNeeded()`'s `Self.onBridgedImagesEvicted?()`
                // read-then-optionally-invoke shape.
                RecipeStore.onBridgedImagesEvicted?()
                readCount.recordInstall()
            }
        }

        #expect(readCount.installCount == 299, "every concurrent read must complete without crashing")
    }
}

/// Thread-safe counter for asserting on cross-thread test outcomes —
/// deliberately independent of the production lock under test.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _installCount = 0
    private var _invocationCount = 0
    private var _winnerIndices: [Int] = []

    var installCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _installCount
    }

    var invocationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _invocationCount
    }

    func recordInstall() {
        lock.lock()
        defer { lock.unlock() }
        _installCount += 1
    }

    func recordWinner(_ index: Int) {
        lock.lock()
        defer { lock.unlock() }
        _invocationCount += 1
        _winnerIndices.append(index)
    }
}
