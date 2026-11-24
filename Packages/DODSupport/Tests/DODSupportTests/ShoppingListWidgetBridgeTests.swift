import Foundation
import Testing

@testable import DODSupport

@Suite("ShoppingListWidgetBridge") struct ShoppingListWidgetBridgeTests {

    static func freshDefaults() throws -> UserDefaults {
        let name = "dod.widget.shopping.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    struct Row {
        let id: UUID
        let ingredientText: String
        let recipeTitle: String
    }

    static func seed(
        _ defaults: UserDefaults,
        rows: [Row],
        checked: [UUID],
        alreadyHave: [UUID]
    ) throws {
        let items: [[String: Any]] = rows.map {
            [
                "id": $0.id.uuidString,
                "ingredientText": $0.ingredientText,
                "recipeTitle": $0.recipeTitle,
                "aisle": "produce",
            ]
        }
        let object: [String: Any] = [
            "items": items,
            "checkedIDs": checked.map(\.uuidString),
            "alreadyHaveIDs": alreadyHave.map(\.uuidString),
        ]
        let data = try JSONSerialization.data(withJSONObject: object)
        defaults.set(data, forKey: ShoppingListWidgetBridge.storageKey)
    }

    @Test func readReturnsNilWhenEmpty() throws {
        let defaults = try Self.freshDefaults()
        #expect(ShoppingListWidgetBridge.read(defaults: defaults) == nil)
    }

    @Test func readCountsAndOrder() throws {
        let defaults = try Self.freshDefaults()
        let firstIngredientID = UUID()
        let secondIngredientID = UUID()
        let thirdIngredientID = UUID()
        try Self.seed(
            defaults,
            rows: [
                Row(id: firstIngredientID, ingredientText: "1 onion", recipeTitle: "Stew"),
                Row(id: secondIngredientID, ingredientText: "2 carrots", recipeTitle: "Stew"),
                Row(id: thirdIngredientID, ingredientText: "salt", recipeTitle: "Stew"),
            ],
            checked: [secondIngredientID],
            alreadyHave: [thirdIngredientID]
        )
        let state = try #require(ShoppingListWidgetBridge.read(defaults: defaults))
        #expect(state.total == 2)
        #expect(state.remaining == 1)
        #expect(state.unchecked.map(\.id) == [firstIngredientID])
        #expect(state.unchecked.map(\.text) == ["1 onion"])
    }

    @Test func listNameSingleVsMixedRecipes() throws {
        let single = try Self.freshDefaults()
        try Self.seed(
            single,
            rows: [
                Row(id: UUID(), ingredientText: "1 onion", recipeTitle: "Stew"),
                Row(id: UUID(), ingredientText: "2 carrots", recipeTitle: "Stew"),
            ],
            checked: [],
            alreadyHave: []
        )
        #expect(ShoppingListWidgetBridge.read(defaults: single)?.listName == "Stew")

        let mixed = try Self.freshDefaults()
        try Self.seed(
            mixed,
            rows: [
                Row(id: UUID(), ingredientText: "1 onion", recipeTitle: "Stew"),
                Row(id: UUID(), ingredientText: "flour", recipeTitle: "Bread"),
            ],
            checked: [],
            alreadyHave: []
        )
        #expect(ShoppingListWidgetBridge.read(defaults: mixed)?.listName == "Shopping List")
    }
}
