import Foundation

/// DUT-1024: a labelled sub-recipe group ("For the Crust"). References
/// ingredients/instructions by id so the flat lists stay the source of truth.
public struct RecipeSection: Sendable, Hashable, Identifiable, Codable {
    public var id: String { label + "\u{1}" + ingredientIDs.map(\.uuidString).joined() }
    public let label: String
    public let ingredientIDs: [UUID]
    public let instructionIDs: [UUID]

    public init(label: String, ingredientIDs: [UUID], instructionIDs: [UUID] = []) {
        self.label = label
        self.ingredientIDs = ingredientIDs
        self.instructionIDs = instructionIDs
    }

    /// Build sections from ordered (label, ingredientCount) groups over a flat list.
    /// Groups with a blank label or count 0 are skipped; counts past the end are clamped.
    public static func make(
        groups: [(label: String, count: Int)],
        ingredients: [RecipeIngredient]
    ) -> [RecipeSection] {
        var cursor = 0
        var result: [RecipeSection] = []
        for group in groups {
            let end = min(cursor + max(group.count, 0), ingredients.count)
            let ids = ingredients[cursor..<end].map(\.id)
            cursor = end
            let label = group.label.trimmingCharacters(in: .whitespacesAndNewlines)
            if !label.isEmpty, !ids.isEmpty {
                result.append(RecipeSection(label: label, ingredientIDs: ids))
            }
        }
        return result
    }
}
