import DODPersistence
import Foundation

extension AppDependencies {

    /// DUT-656 — one-shot latch so a second `AppDependencies()` (tests, previews,
    /// or a spurious composition-root rebuild) can't clobber the already-installed
    /// hook. `RecipeStore.onBridgedImagesEvicted` is a process-global; registering
    /// it exactly once keeps the live reload closure stable for the process.
    /// Guarded by a lock because `AppDependencies.init` is `@MainActor` but this
    /// static is `nonisolated`.
    private static let evictionHookLock = NSLock()
    nonisolated(unsafe) private static var evictionHookInstalled = false

    /// DUT-475 — install the `RecipeStore.onBridgedImagesEvicted` delivery hook.
    /// Extracted from `init` as the testable seam: the hook the production evict
    /// path fires is wired before any UI (called from `init`, before `bootstrap()`),
    /// so an eviction that lands before / around `bootstrap()` is still delivered —
    /// closing the DUT-475 window where an early feed-driven eviction observed a
    /// still-nil hook. `WidgetCenter.reloadAllTimelines()` is itself thread-safe, so
    /// the call context is fine.
    ///
    /// DUT-656 — idempotent: only the FIRST call installs the hook; subsequent
    /// calls are no-ops so the global isn't clobbered by a re-built root.
    static func installBridgedEvictionHook(_ reload: @escaping @Sendable () -> Void) {
        evictionHookLock.lock()
        defer { evictionHookLock.unlock() }
        guard !evictionHookInstalled else { return }
        evictionHookInstalled = true
        RecipeStore.onBridgedImagesEvicted = reload
    }
}
