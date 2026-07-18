import DODPersistence

extension AppDependencies {

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
    ///
    /// The check-then-set + every read now live behind ONE lock owned by
    /// `RecipeStore` itself (``RecipeStore/installEvictionHookIfNeeded(_:)``),
    /// so this is a true atomic compare-and-set rather than a lock here that
    /// only covered the write while the store-actor's read went unguarded —
    /// see that method's doc comment for the race this used to leave open.
    static func installBridgedEvictionHook(_ reload: @escaping @Sendable () -> Void) {
        RecipeStore.installEvictionHookIfNeeded(reload)
    }
}
