import DODPersistence
import Foundation

extension AppDependencies {

    /// DUT-475 — install the `RecipeStore.onBridgedImagesEvicted` delivery hook.
    /// Extracted from `init` as the testable seam: the hook the production evict
    /// path fires is wired before any UI (called from `init`, before `bootstrap()`),
    /// so an eviction that lands before / around `bootstrap()` is still delivered —
    /// closing the DUT-475 window where an early feed-driven eviction observed a
    /// still-nil hook. `WidgetCenter.reloadAllTimelines()` is itself thread-safe, so
    /// the call context is fine.
    static func installBridgedEvictionHook(_ reload: @escaping @Sendable () -> Void) {
        RecipeStore.onBridgedImagesEvicted = reload
    }
}
