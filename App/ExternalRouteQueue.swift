import Foundation

/// A FIFO mailbox of pending ``ExternalRoute``s for one tab's `NavigationStack`.
///
/// Replaces the former single-slot `ExternalRoute?` sink, which lost routes in
/// three ways (all one root cause — an async, mount-gated consumer draining a
/// one-deep slot):
///
/// - **DUT-464** — a second route landing before the first is consumed
///   overwrote it. The queue holds every enqueued route so none is dropped when
///   two inline links resolve within a frame.
/// - **DUT-463 / DUT-319** — a route resolved while its tab is unmounted (the
///   `.task(id:)` consumer is cancelled: iPhone tab hidden, iPad TabStack torn
///   down via `.id(selectedTab)`) sat unconsumed until the tab was next opened,
///   then replaced whatever stack the user had built — minutes/hours later, with
///   no visible cause. The queue is drained on tab *appear*, so a route that
///   arrived while unmounted still fires the moment the tab mounts; and
///   ``drain(now:)`` drops routes older than ``staleAfter`` so a long-stale
///   route is discarded instead of silently wiping the stack.
///
/// Pure value type with an injected clock so the enqueue / staleness / drain
/// contract is unit-testable without a SwiftUI host (mirrors
/// ``RecipeRouteResolver`` and ``RootView/linkRoutingDestination(for:)``).
struct ExternalRouteQueue: Equatable {

    /// A pending route paired with the instant it was enqueued, so ``drain(now:)``
    /// can discard routes that have outlived ``staleAfter``.
    struct Pending: Equatable {
        let route: ExternalRoute
        let enqueuedAt: Date
    }

    /// Routes older than this at drain time are dropped rather than delivered.
    /// A deep link that resolved while its tab was hidden should still fire when
    /// the user returns *promptly*; but one that has sat for minutes (the DUT-463
    /// scenario — the user built an unrelated stack in the meantime) must not
    /// suddenly replace their navigation. Five seconds comfortably covers a
    /// cache-miss REST fetch on poor connectivity while excluding the
    /// leave-and-return-much-later case.
    static let staleAfter: TimeInterval = 5

    private(set) var pending: [Pending] = []

    /// Append a route without dropping any already-queued one (DUT-464). FIFO —
    /// routes are delivered in the order they landed.
    ///
    /// Skips the append when an **equal** route is already queued — a
    /// double-tap on an in-app recipe link (or any other duplicate resolve
    /// landing before the first is drained) previously enqueued the same
    /// `ExternalRoute` twice, and `TabStack.consumeExternalRoutes()` applied
    /// both: a `.push` appended the identical `RecipeRoute` onto the
    /// `NavigationStack` path twice, so the user had to tap Back an extra
    /// time to escape what looked like a single link tap. `ExternalRoute`
    /// (via `RecipeRoute`'s DUT-617/658 id-based equality) already compares
    /// cheaply and correctly, so this is a plain containment check — not a
    /// new identity scheme. Only the `.route` field is compared, not
    /// `enqueuedAt`, so two genuinely-distinct-but-coincidentally-timed
    /// enqueues of the same route still collapse to one.
    mutating func enqueue(_ route: ExternalRoute, now: Date = Date()) {
        guard !pending.contains(where: { $0.route == route }) else { return }
        pending.append(Pending(route: route, enqueuedAt: now))
    }

    /// Remove and return every non-stale queued route in arrival order, clearing
    /// the queue. Routes older than ``staleAfter`` are discarded (DUT-463) and
    /// never returned. Call on tab appear and whenever the queue changes so a
    /// route enqueued while the tab was unmounted is delivered once it mounts
    /// (DUT-463 / DUT-319).
    mutating func drain(now: Date = Date()) -> [ExternalRoute] {
        let fresh = pending.filter { now.timeIntervalSince($0.enqueuedAt) <= Self.staleAfter }
        pending.removeAll()
        return fresh.map(\.route)
    }

    /// `true` when nothing is queued — lets the view avoid a needless drain pass.
    var isEmpty: Bool { pending.isEmpty }
}
