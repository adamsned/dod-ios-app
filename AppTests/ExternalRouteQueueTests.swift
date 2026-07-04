import DODDomain
import Foundation
import XCTest

@testable import DODApp

/// DUT-463 / DUT-464 / DUT-319 — the external-route sink is a FIFO queue, not a
/// single-slot mailbox. These pin the delivery contract the `TabStack` drain
/// relies on (the pure value type is testable with no SwiftUI host, mirroring
/// `RecipeRouteResolverTests`):
///
/// - **DUT-464** — a second route enqueued before the first is drained is NOT
///   dropped; both are delivered, in arrival order.
/// - **DUT-463 / DUT-319** — a route that resolves while its tab is unmounted
///   is held in the queue and delivered whole when the tab next mounts and
///   drains; but a route that has gone stale (sat past `staleAfter`) is
///   discarded rather than silently replacing the user's stack minutes later.
final class ExternalRouteQueueTests: XCTestCase {

    private func url(_ string: String) -> URL {
        URL(string: string) ?? URL(filePath: "/")
    }

    private func listItem(id: Int) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: "Recipe \(id)",
            excerpt: "",
            publishedAt: .distantPast,
            canonicalURL: url("https://www.dutchovendaddy.com/recipe-\(id)/")
        )
    }

    private func route(id: Int) -> ExternalRoute {
        .replaceStack(.recipe(item: listItem(id: id)))
    }

    private func pushRoute(id: Int) -> ExternalRoute {
        .push(.recipe(item: listItem(id: id)))
    }

    /// Extract the recipe id from an `ExternalRoute`, whichever case it is, so
    /// order assertions read cleanly.
    private func recipeID(_ route: ExternalRoute) -> Int? {
        let recipeRoute: RecipeRoute
        switch route {
        case .replaceStack(let inner), .push(let inner): recipeRoute = inner
        }
        guard case .recipe(let item, _) = recipeRoute else { return nil }
        return item.id
    }

    // MARK: - DUT-464: no route is dropped

    /// AC: enqueuing a second route before draining keeps BOTH — the pre-fix
    /// single slot overwrote the first. FIFO, so they drain in arrival order.
    func test_twoRapidRoutes_bothDelivered_inOrder() {
        var queue = ExternalRouteQueue()
        queue.enqueue(pushRoute(id: 11))
        queue.enqueue(pushRoute(id: 22))

        let drained = queue.drain()

        XCTAssertEqual(drained.map(recipeID), [11, 22], "both routes must survive, in order")
        XCTAssertTrue(queue.isEmpty, "drain clears the queue")
    }

    // MARK: - DUT-463 / DUT-319: unmounted-tab delivery + staleness

    /// AC: a route enqueued while the tab is unmounted survives in the queue
    /// and is delivered on the next drain (the tab mounting) — the DUT-463 /
    /// DUT-319 "route resolved while the tab is gone" case. Fresh routes are
    /// never dropped.
    func test_routeEnqueuedWhileUnmounted_deliveredOnNextDrain() {
        let now = Date()
        var queue = ExternalRouteQueue()
        // Landed while the tab was unmounted, a beat ago (still fresh).
        queue.enqueue(route(id: 42), now: now)

        // Tab mounts and drains shortly after.
        let drained = queue.drain(now: now.addingTimeInterval(1))

        XCTAssertEqual(drained.map(recipeID), [42], "a fresh unmounted-tab route must still fire on mount")
    }

    /// AC: a route that has outlived `staleAfter` at drain time is discarded,
    /// not delivered — so a deep link that resolved while Feed was hidden and
    /// then sat for minutes (user built an unrelated stack) does NOT suddenly
    /// wipe their navigation (DUT-463 root complaint).
    func test_staleRoute_isDroppedNotDelivered() {
        let now = Date()
        var queue = ExternalRouteQueue()
        queue.enqueue(route(id: 7), now: now)

        let drained = queue.drain(now: now.addingTimeInterval(ExternalRouteQueue.staleAfter + 1))

        XCTAssertTrue(drained.isEmpty, "a long-stale route must be dropped rather than replace the stack")
        XCTAssertTrue(queue.isEmpty, "drain clears even dropped routes")
    }

    /// AC: staleness is per-route — a stale route is dropped while a fresh one
    /// enqueued later is still delivered in the same drain.
    func test_mixedFreshAndStale_onlyFreshDelivered() {
        let now = Date()
        var queue = ExternalRouteQueue()
        queue.enqueue(route(id: 1), now: now)  // will be stale
        queue.enqueue(route(id: 2), now: now.addingTimeInterval(ExternalRouteQueue.staleAfter + 3))

        let drained = queue.drain(now: now.addingTimeInterval(ExternalRouteQueue.staleAfter + 4))

        XCTAssertEqual(drained.map(recipeID), [2], "the stale route is dropped, the fresh one delivered")
    }

    /// AC: an empty queue reports empty and drains to nothing — the `TabStack`
    /// guard skips a needless drain pass.
    func test_emptyQueue_isEmpty_andDrainsToNothing() {
        var queue = ExternalRouteQueue()
        XCTAssertTrue(queue.isEmpty)
        XCTAssertTrue(queue.drain().isEmpty)
    }
}
