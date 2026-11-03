import Foundation

public struct ShoppingListWidgetItem: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let text: String
    public init(id: UUID, text: String) {
        self.id = id
        self.text = text
    }
}
