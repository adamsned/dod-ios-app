import Foundation

/// DUT-1004: a recipe the cook brought in themselves (a scanned family card).
/// Local-only: unlike `Recipe` it has no WP post id and no canonical URL.
/// Reuses the shared ingredient / instruction line types.
public struct FamilyRecipe: Sendable, Hashable, Identifiable, Codable {
    public let id: UUID
    public let title: String
    public let ingredients: [RecipeIngredient]
    public let instructions: [RecipeInstruction]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        ingredients: [RecipeIngredient],
        instructions: [RecipeInstruction],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.ingredients = ingredients
        self.instructions = instructions
        self.createdAt = createdAt
    }
}
