import Foundation
import Testing

@testable import DODFeatureRecipeDetail

/// DUT-474 — the once-per-process reconcile flag could never end an in-process
/// orphan (a controller whose scene was destroyed without `endCookMode`). The
/// registry-based reconcile ends any existing activity whose id is NOT held by a
/// live controller, on every construction. These exercise the platform-neutral
/// core the ActivityKit-backed controller delegates to.
@Suite("Cook Live Activity orphan registry (DUT-474)")
struct CookLiveActivityOrphanRegistryTests {

    @Test func aRegisteredIDIsNotAnOrphan() {
        let registry = CookLiveActivityOrphanRegistry()
        registry.register("live-1")

        #expect(registry.isRegistered("live-1"))
        // The installed controller's own card is spared (DUT-431 no-kill).
        #expect(registry.orphanIDs(amongExisting: ["live-1"]).isEmpty)
    }

    @Test func anUnregisteredExistingIDIsAnOrphan() {
        let registry = CookLiveActivityOrphanRegistry()
        registry.register("live-1")

        // A cross-process orphan (never registered in THIS process) is ended.
        #expect(registry.orphanIDs(amongExisting: ["live-1", "orphan-x"]) == ["orphan-x"])
    }

    /// The core DUT-474 case: a controller registers its id, then deallocates
    /// (scene destroyed) — its `deinit` unregisters the id. The card still exists
    /// on the Lock Screen, but the next construction's reconcile now sees it as an
    /// orphan (no live controller holds it) and ends it. Pre-fix, the once-flag
    /// meant no path could ever end it.
    @Test func aDeallocatedControllersIDBecomesAnOrphanAfterUnregister() {
        let registry = CookLiveActivityOrphanRegistry()
        registry.register("scene-orphan")
        #expect(registry.orphanIDs(amongExisting: ["scene-orphan"]).isEmpty)  // still owned

        // Simulate the controller's `deinit` on whole-scene teardown.
        registry.unregister("scene-orphan")

        #expect(registry.isRegistered("scene-orphan") == false)
        // Now the still-existing card is reconcilable — every construction, not
        // just once per process.
        #expect(registry.orphanIDs(amongExisting: ["scene-orphan"]) == ["scene-orphan"])
    }

    @Test func orphanReconcileSparesLiveAndEndsDeadAcrossMany() {
        let registry = CookLiveActivityOrphanRegistry()
        registry.register("a")
        registry.register("c")

        // b + d are orphans; a + c are live. Order preserved for determinism.
        #expect(registry.orphanIDs(amongExisting: ["a", "b", "c", "d"]) == ["b", "d"])
    }
}
