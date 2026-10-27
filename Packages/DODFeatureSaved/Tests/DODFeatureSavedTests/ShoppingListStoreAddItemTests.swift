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

    @Test func addItemTrimsAndRejectsEmpty() throws {
        let store = try makeStore()
        #expect(store.addItem(text: "  ") == false)
        #expect(store.load() == nil)
        #expect(store.addItem(text: "  butter "))
        #expect(store.load()?.items.map(\.ingredientText) == ["butter"])
    }

    @Test func addItemDedups() throws {
        let store = try makeStore()
        #expect(store.addItem(text: "butter"))
        #expect(store.addItem(text: "butter") == false)
        #expect(store.load()?.items.count == 1)
    }
}
