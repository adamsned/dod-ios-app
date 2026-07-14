import DODDomain
import Foundation
import Testing

@testable import DODApp

/// Regression coverage for the `ExternalRouteQueue.enqueue(_:now:)` dedupe fix.
///
/// Before the fix, `enqueue` appended unconditionally: a double-tap on an
/// in-app recipe link (or any other duplicate resolve landing before the
/// queue was drained) enqueued the SAME `ExternalRoute` twice, and
/// `TabStack.consumeExternalRoutes()` applied both — a `.push` appended the
/// identical `RecipeRoute` onto the `NavigationStack` path twice, so the user
/// had to tap Back an extra time to escape what looked like a single link
/// tap. These tests pin: (1) a genuine duplicate collapses to one delivered
/// route, (2) two distinct routes are never deduped against each other, and
/// (3) the same recipe id enqueued under different `ExternalRoute` cases
/// (`.push` vs `.replaceStack`) is NOT collapsed — those are distinct sink
/// semantics (DUT-243), not duplicates.
@Suite("ExternalRouteQueue enqueue dedupe")
struct ExternalRouteQueueDedupeTests {

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

    private func pushRoute(id: Int) -> ExternalRoute {
        .push(.recipe(item: listItem(id: id)))
    }

    private func replaceStackRoute(id: Int) -> ExternalRoute {
        .replaceStack(.recipe(item: listItem(id: id)))
    }

    /// THE FIX: a double-tap that resolves to the same route twice before the
    /// queue is drained must deliver it only once — not push the same recipe
    /// onto the NavigationStack path twice.
    @Test("enqueueing the same route twice before drain delivers it only once")
    func enqueueingSameRouteTwice_isDeduped() {
        var queue = ExternalRouteQueue()
        let now = Date()

        queue.enqueue(pushRoute(id: 42), now: now)
        // The second tap resolves a beat later, but well within staleAfter —
        // the scenario this fix targets, not a stale-drop.
        queue.enqueue(pushRoute(id: 42), now: now.addingTimeInterval(0.2))

        let drained = queue.drain(now: now.addingTimeInterval(0.4))

        #expect(drained.count == 1, "a duplicate route must not survive the enqueue twice")
        #expect(queue.isEmpty, "drain clears the queue")
    }

    /// Two genuinely different routes (different recipe ids) must never be
    /// deduped against each other — only an exact-equal route collapses.
    @Test("enqueueing two different routes delivers both, in order")
    func enqueueingTwoDifferentRoutes_bothSurvive() {
        var queue = ExternalRouteQueue()
        let now = Date()

        queue.enqueue(pushRoute(id: 11), now: now)
        queue.enqueue(pushRoute(id: 22), now: now.addingTimeInterval(0.1))

        let drained = queue.drain(now: now.addingTimeInterval(0.2))

        #expect(drained == [pushRoute(id: 11), pushRoute(id: 22)], "distinct routes must both survive, in FIFO order")
    }

    /// The same recipe id enqueued once as `.push` and once as `.replaceStack`
    /// carries different NavigationStack sink semantics (DUT-243), so the two
    /// `ExternalRoute` values are NOT equal and must NOT be deduped away.
    @Test("the same recipe id under different ExternalRoute cases is not deduped")
    func sameRecipeID_differentExternalRouteCase_bothSurvive() {
        var queue = ExternalRouteQueue()
        let now = Date()

        queue.enqueue(pushRoute(id: 42), now: now)
        queue.enqueue(replaceStackRoute(id: 42), now: now.addingTimeInterval(0.1))

        let drained = queue.drain(now: now.addingTimeInterval(0.2))

        #expect(
            drained == [pushRoute(id: 42), replaceStackRoute(id: 42)],
            "push and replaceStack are distinct sink semantics, not duplicates"
        )
    }
}
