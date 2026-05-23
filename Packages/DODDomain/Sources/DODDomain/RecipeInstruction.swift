import Foundation

/// One instruction step. Handles both `recipeInstructions: [String]` and
/// `[HowToStep]` shapes from JSON-LD (resolved in the parser, T-059).
/// Spec trace: spec.md AC-4.3.
public struct RecipeInstruction: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    /// 1-based step number.
    public let step: Int
    public let text: String

    public init(id: UUID = UUID(), step: Int, text: String) {
        self.id = id
        self.step = step
        self.text = text
    }
}
