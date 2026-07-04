import Foundation

/// DUT-474 — process-wide registry of the Live Activity ids currently held by a
/// LIVE ``SystemCookLiveActivityController``, plus the orphan-reconcile decision
/// that keys off it.
///
/// Extracted from the ActivityKit-backed controller (which only compiles its real
/// paths under `#if os(iOS)`) so the registry + reconcile logic is
/// platform-neutral and unit-testable on the macOS `swift test` slice.
///
/// **Why a registry, not a once-per-process flag (DUT-431 → DUT-474).** DUT-431
/// replaced a per-instance reconcile — which killed the card the *installed*
/// controller was legitimately driving after a SwiftUI re-render — with a pure
/// once-per-process flag. But that flag can NEVER reconcile an *in-process*
/// orphan: a controller whose hosting scene is destroyed (iPad App Exposé) without
/// `onDisappear`/`endCookMode` deallocates still holding a card, and no later
/// construction can end it. Keying reconcile off known-live ids fixes both cases:
/// the installed controller registers its id (so it's spared), a deallocated
/// controller's `deinit` unregisters its id (so its card becomes an orphan the
/// next construction ends), and a cross-process orphan (DUT-309) was never
/// registered in this process at all (so it's ended too).
///
/// Thread-safe (lock-guarded) so a nonisolated `deinit` can unregister safely.
final class CookLiveActivityOrphanRegistry: @unchecked Sendable {

    static let shared = CookLiveActivityOrphanRegistry()

    private let lock = NSLock()
    private var liveIDs: Set<String> = []

    /// Test seam: a fresh, isolated registry so a test never contends with the
    /// process-wide `shared` instance or another test's leftover ids.
    init() {}

    func register(_ id: String) {
        lock.lock()
        defer { lock.unlock() }
        liveIDs.insert(id)
    }

    func unregister(_ id: String) {
        lock.lock()
        defer { lock.unlock() }
        liveIDs.remove(id)
    }

    func isRegistered(_ id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return liveIDs.contains(id)
    }

    /// Of the currently-existing activity ids, the ones that are orphans — i.e.
    /// not held by any live controller — and so should be ended on reconcile.
    /// Order-preserving on `existingIDs` for deterministic tests.
    func orphanIDs(amongExisting existingIDs: [String]) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return existingIDs.filter { !liveIDs.contains($0) }
    }
}
