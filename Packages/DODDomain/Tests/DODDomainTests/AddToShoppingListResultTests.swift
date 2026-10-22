import Foundation
import Testing

@testable import DODDomain

/// DUT-534: ``AddToShoppingListResult`` is the outcome the shared
/// "Add to Shopping List" affordance branches on to pick its Snackbar copy.
@Suite("AddToShoppingListResult") struct AddToShoppingListResultTests {

    @Test func addedWithSameCountIsEqual() {
        #expect(AddToShoppingListResult.added(count: 3) == .added(count: 3))
    }

    @Test func addedWithDifferentCountIsNotEqual() {
        #expect(AddToShoppingListResult.added(count: 3) != .added(count: 4))
    }

    @Test func couldntLoadEqualsItself() {
        #expect(AddToShoppingListResult.couldntLoad == .couldntLoad)
    }

    /// `.added(count: 0)` is a distinct value from `.couldntLoad` (the
    /// appender folds it into `.couldntLoad`, but the enum itself keeps them apart).
    @Test func addedZeroIsNotCouldntLoad() {
        #expect(AddToShoppingListResult.added(count: 0) != .couldntLoad)
    }

    @Test func addedIsNotCouldntLoad() {
        #expect(AddToShoppingListResult.added(count: 5) != .couldntLoad)
    }

    @Test func addedCarriesItsCount() {
        let result = AddToShoppingListResult.added(count: 7)
        guard case .added(let count) = result else {
            Issue.record("expected .added, got \(result)")
            return
        }
        #expect(count == 7)
    }

    @Test func couldntLoadDoesNotMatchAdded() {
        let result = AddToShoppingListResult.couldntLoad
        if case .added = result {
            Issue.record("couldntLoad must not match .added")
        }
    }

    /// The enum is `Sendable`, so a result can cross into a detached task.
    @Test func resultCrossesATaskBoundary() async {
        let result = AddToShoppingListResult.added(count: 2)
        let echoed = await Task.detached { result }.value
        #expect(echoed == .added(count: 2))
    }
}
