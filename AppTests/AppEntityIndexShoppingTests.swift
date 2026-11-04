import DODFeatureSaved
import Foundation
import Testing

@testable import DODApp

@Suite("AppEntityIndex shopping entities")
struct AppEntityIndexShoppingTests {

    @Test
    func returnsOnlyUncheckedNotAlreadyHaveItems() {
        let keep = Self.item("2 cups flour")
        let checked = Self.item("1 tsp salt")
        let have = Self.item("1 onion")
        let snapshot = ShoppingListStore.Snapshot(
            items: [keep, checked, have],
            checkedIDs: [checked.id],
            alreadyHaveIDs: [have.id]
        )

        let entities = AppEntityIndex.shoppingEntities(from: snapshot)

        #expect(entities.count == 1)
        #expect(entities.first?.id == keep.id)
        #expect(entities.first?.text == "2 cups flour")
    }

    @Test
    func nilSnapshotReturnsEmpty() {
        #expect(AppEntityIndex.shoppingEntities(from: nil).isEmpty)
    }

    private static func item(_ text: String) -> ShoppingListViewModel.Item {
        ShoppingListViewModel.Item(ingredientText: text, recipeTitle: "Bread", aisle: .pantry)
    }
}
