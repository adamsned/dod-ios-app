import DODFeatureSaved
import Foundation
import Testing

@testable import DODApp

@Suite("Shopping List Item Entity Tests")
struct ShoppingListEntityTests {

    @Test("Nil snapshot gives empty array")
    func nilSnapshot() {
        #expect(ShoppingListItemEntityQuery.payloads(from: nil).isEmpty)
    }

    @Test("Snapshot with one item and one already-have ID gives two items")
    func snapshotWithAlreadyHaveItem() {
        let id1 = UUID()
        let id2 = UUID()

        let snapshot = ShoppingListStore.Snapshot(
            items: [
                ShoppingListViewModel.Item(ingredientText: "flour", recipeTitle: "Bread", aisle: .pantry),
                ShoppingListViewModel.Item(ingredientText: "salt", recipeTitle: "Bread", aisle: .spices),
            ],
            checkedIDs: [],
            alreadyHaveIDs: [id1]
        )

        let payloads = ShoppingListItemEntityQuery.payloads(from: snapshot)
        #expect(payloads.count == 1)
        #expect(payloads[0].id == id2)
        #expect(payloads[0].text == "salt")
        #expect(payloads[0].recipeTitle == "Bread")
        #expect(payloads[0].isChecked == false)
    }

    @Test("Checked items have isChecked = true")
    func checkedItems() {
        let id1 = UUID()
        let id2 = UUID()

        let snapshot = ShoppingListStore.Snapshot(
            items: [
                ShoppingListViewModel.Item(ingredientText: "flour", recipeTitle: "Bread", aisle: .pantry),
                ShoppingListViewModel.Item(ingredientText: "salt", recipeTitle: "Bread", aisle: .spices),
            ],
            checkedIDs: [id1],
            alreadyHaveIDs: []
        )

        let payloads = ShoppingListItemEntityQuery.payloads(from: snapshot)
        #expect(payloads.count == 2)
        #expect(payloads[0].id == id1)
        #expect(payloads[0].text == "flour")
        #expect(payloads[0].recipeTitle == "Bread")
        #expect(payloads[0].isChecked == true)
        #expect(payloads[1].id == id2)
        #expect(payloads[1].text == "salt")
        #expect(payloads[1].recipeTitle == "Bread")
        #expect(payloads[1].isChecked == false)
    }
}
