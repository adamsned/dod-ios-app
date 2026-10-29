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

extension BringList {
    /// Seed from planned recipes. `equipment` is the union of each recipe's `[Equipment]`.
    /// De-dupes by lowercased trimmed name (first image wins), skips blank names, then adds
    /// a charcoal row and, unless an oven is already present, a default Dutch oven row.
    public static func seed(equipment: [Equipment], totalServings: Int?) -> BringList {
        var items: [BringListItem] = []
        var seen = Set<String>()
        for gear in equipment {
            let trimmed = gear.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            items.append(
                BringListItem(
                    id: key,
                    name: trimmed,
                    category: BringListGearClassifier.classify(trimmed),
                    imageURL: gear.imageURL
                )
            )
        }
        let coalName = "Charcoal briquettes"
        if seen.insert(coalName.lowercased()).inserted {
            items.append(
                BringListItem(
                    id: coalName.lowercased(),
                    name: coalName,
                    category: .fuel,
                    quantity: BringListCoalPlanner.briquettesToPack(servings: totalServings)
                )
            )
        }
        if !items.contains(where: { $0.category == .ovens }) {
            items.append(
                BringListItem(
                    id: "dutch oven",
                    name: "Dutch oven",
                    category: .ovens,
                    quantity: BringListCoalPlanner.ovenCount(servings: totalServings)
                )
            )
        }
        return BringList(items: items)
    }
}
