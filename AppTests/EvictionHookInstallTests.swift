import DODPersistence
import Foundation
import XCTest

@testable import DODApp

/// DUT-475 — `RecipeStore.onBridgedImagesEvicted` (the widget-reload hook fired by
/// `evictImagesIfNeeded`) used to be assigned inside `bootstrap()`, which runs
/// from `RootView.task` and races the same view's body: an established install
/// with a near-budget image cache can evict in the first ~100ms, BEFORE bootstrap
/// reaches the assignment — that eviction's reload is silently dropped, and the
/// store-actor read of the still-nil `nonisolated(unsafe)` hook races the write.
///
/// The fix installs the hook in `AppDependencies.init` (before any UI exists), via
/// the ``AppDependencies/installBridgedEvictionHook(_:)`` seam. These pin the
/// contract with the real static hook as the eviction publisher + a spy, no UI
/// host and no `bootstrap()` call — the hook must already deliver before bootstrap
/// would have run.
@MainActor
final class EvictionHookInstallTests: XCTestCase {

    override func tearDown() {
        // Don't leak a test spy into other tests that share the process-wide static.
        RecipeStore.onBridgedImagesEvicted = nil
        super.tearDown()
    }

    /// An eviction firing after `installBridgedEvictionHook` (i.e. after `init`)
    /// but BEFORE `bootstrap()` ever runs is still delivered to the hook.
    func testEvictionBeforeBootstrapIsDelivered() {
        RecipeStore.onBridgedImagesEvicted = nil  // simulate a fresh process
        let spy = ReloadSpy()

        // This is exactly what `AppDependencies.init` now does — pre-UI, pre-bootstrap.
        AppDependencies.installBridgedEvictionHook { spy.record() }

        // The store-actor evict path fires this static; simulate an eviction that
        // lands in the first ~100ms, before any `bootstrap()` assignment would run.
        RecipeStore.onBridgedImagesEvicted?()

        XCTAssertEqual(spy.count, 1, "hook installed in init must catch a pre-bootstrap eviction")
    }

    /// The install seam actually points the process-wide static at the given
    /// closure (so the persistence evict path, which reads that static, delivers).
    func testInstallAssignsTheProcessWideHook() {
        RecipeStore.onBridgedImagesEvicted = nil
        let spy = ReloadSpy()
        AppDependencies.installBridgedEvictionHook { spy.record() }
        XCTAssertNotNil(RecipeStore.onBridgedImagesEvicted)
        RecipeStore.onBridgedImagesEvicted?()
        RecipeStore.onBridgedImagesEvicted?()
        XCTAssertEqual(spy.count, 2)
    }

    private final class ReloadSpy: @unchecked Sendable {
        private let lock = NSLock()
        private var _count = 0
        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return _count
        }
        func record() {
            lock.lock()
            defer { lock.unlock() }
            _count += 1
        }
    }
}
