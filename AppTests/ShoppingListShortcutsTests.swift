import DODFeatureSaved
import Foundation
import Testing

@testable import DODApp

@Suite("Shopping List Shortcuts Tests")
struct ShoppingListShortcutsTests {

    @Test("App shortcuts stay within Apple's cap of 10")
    func underCap() {
        #expect(DODShortcuts.appShortcuts.count <= 10)
    }

    @Test("Both shopping list intents can be instantiated")
    func intentsInstantiate() {
        _ = ReadShoppingListIntent()
        _ = AddShoppingListItemIntent()
    }

    @Test("Read summary for an empty list")
    func emptySummary() {
        #expect(ReadShoppingListIntent.spokenSummary(from: []) == "Your shopping list is empty.")
    }

    @Test("Add dialog copy has no em dash")
    func addDialog() {
        #expect(AddShoppingListItemIntent.dialog(item: "milk", added: true) == "Added milk to your list.")
        #expect(AddShoppingListItemIntent.dialog(item: "milk", added: false) == "milk is already on your list.")
        #expect(!AddShoppingListItemIntent.dialog(item: "milk", added: true).contains("\u{2014}"))
    }
}
