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
}
