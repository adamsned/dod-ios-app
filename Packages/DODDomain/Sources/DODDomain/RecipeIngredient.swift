import Foundation

/// One ingredient line from JSON-LD `recipeIngredient`.
/// Stored as raw text; the JSON-LD shape has no per-ingredient ID.
/// Spec trace: spec.md AC-4.2.
public struct RecipeIngredient: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    public let text: String

    public init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}
