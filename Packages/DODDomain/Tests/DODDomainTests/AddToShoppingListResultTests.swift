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
}
