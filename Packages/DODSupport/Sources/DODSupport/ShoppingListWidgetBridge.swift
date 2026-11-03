import Foundation

public struct ShoppingListWidgetItem: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let text: String
    public init(id: UUID, text: String) {
        self.id = id
        self.text = text
    }
}

public struct ShoppingListWidgetState: Equatable, Sendable {
    public let listName: String
    public let total: Int
    public let remaining: Int
    public let unchecked: [ShoppingListWidgetItem]
    public init(listName: String, total: Int, remaining: Int, unchecked: [ShoppingListWidgetItem]) {
        self.listName = listName
        self.total = total
        self.remaining = remaining
        self.unchecked = unchecked
    }
}

public enum ShoppingListWidgetBridge {
    /// Must equal `ShoppingListStore.key`.
    public static let storageKey = "dod.shoppingList.v1"
    public static let kind = "ShoppingListWidget"

    private struct Blob: Decodable {
        struct Row: Decodable {
            let id: UUID
            let ingredientText: String
            let recipeTitle: String
        }
        let items: [Row]
        let checkedIDs: [UUID]
        let alreadyHaveIDs: [UUID]
    }
}
