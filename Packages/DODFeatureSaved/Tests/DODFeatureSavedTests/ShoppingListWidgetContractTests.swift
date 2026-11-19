import DODSupport
import Foundation
import Testing

@testable import DODFeatureSaved

/// DUT-2123 — locks the wire contract between the app's ShoppingListStore and
/// the widget's ShoppingListWidgetBridge.
@MainActor
@Suite("Shopping list widget contract (DUT-2123)") struct ShoppingListWidgetContractTests {

    @Test func widgetBridgeReadsWhatStoreSaved() throws {
        let defaults = try Self.freshDefaults()
        let store = ShoppingListStore(defaults: defaults)
        let onion = ShoppingListViewModel.Item(
            ingredientText: "1 onion",
            recipeTitle: "R",
            aisle: .produce
        )
        let salt = ShoppingListViewModel.Item(
            ingredientText: "1 tsp salt",
            recipeTitle: "R",
            aisle: .spices
        )

        store.save(items: [onion, salt], checked: [onion.id], alreadyHave: [])

        let state = try #require(ShoppingListWidgetBridge.read(defaults: defaults))
        #expect(state.total == 2)
        #expect(state.remaining == 1)
    }

    @Test func bridgeKeyMatchesStoreKey() {
        #expect(ShoppingListWidgetBridge.storageKey == ShoppingListStore.key)
    }

    private static func freshDefaults() throws -> UserDefaults {
        let name = "dod.shoppingList.widgetContract.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
