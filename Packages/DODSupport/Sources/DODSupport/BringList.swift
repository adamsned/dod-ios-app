import DODDomain
import Foundation

public struct BringListItem: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let category: BringListCategory
    public let imageURL: URL?
    public let quantity: Int
    public var isPacked: Bool

    public init(
        id: String,
        name: String,
        category: BringListCategory,
        imageURL: URL? = nil,
        quantity: Int = 1,
        isPacked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.imageURL = imageURL
        self.quantity = quantity
        self.isPacked = isPacked
    }
}

public struct BringList: Codable, Sendable, Equatable {
    public var items: [BringListItem]

    public init(items: [BringListItem] = []) { self.items = items }

    public mutating func togglePacked(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPacked.toggle()
    }

    /// Items grouped by category in BringListCategory.allCases order, empty groups omitted.
    public func grouped() -> [(category: BringListCategory, items: [BringListItem])] {
        BringListCategory.allCases.compactMap { category in
            let rows = items.filter { $0.category == category }
            return rows.isEmpty ? nil : (category, rows)
        }
    }
}
