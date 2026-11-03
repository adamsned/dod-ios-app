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
