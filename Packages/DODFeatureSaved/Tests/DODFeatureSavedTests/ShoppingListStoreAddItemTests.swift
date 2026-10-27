import Foundation
import Testing

@testable import DODFeatureSaved

@Suite struct ShoppingListStoreAddItemTests {
    private func makeStore() throws -> ShoppingListStore {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        return ShoppingListStore(defaults: defaults)
    }

    @Test func addItemAppendsRow() throws {
        let store = try makeStore()
        #expect(store.addItem(text: "butter"))
        #expect(store.load()?.items.map(\.ingredientText) == ["butter"])
    }
}
