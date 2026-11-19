import Foundation

/// DUT-979 - category for a Bring List row. Distinct from the ingredient aisles.
public enum BringListCategory: String, CaseIterable, Sendable, Codable {
    case ovens, fuel, tools, transport, other
}

/// Pure keyword classifier mapping a piece of equipment name to a ``BringListCategory``.
public enum BringListGearClassifier {
    public static func classify(_ name: String) -> BringListCategory {
        let lowercasedName = name.lowercased()
        guard !lowercasedName.isEmpty else { return .other }
        for (keyword, category) in keywords where lowercasedName.contains(keyword) { return category }
        return .other
    }

    // Ordered array (not a Dictionary) so matching is deterministic.
    private static let keywords: [(String, BringListCategory)] = [
        ("dutch oven", .ovens), ("camp oven", .ovens),
        ("charcoal", .fuel), ("briquette", .fuel), ("chimney", .fuel), ("lighter", .fuel),
        ("glove", .tools), ("lid lifter", .tools), ("tongs", .tools), ("lid stand", .tools),
        ("table", .transport), ("cooler", .transport), ("cart", .transport), ("box", .transport),
    ]
}
