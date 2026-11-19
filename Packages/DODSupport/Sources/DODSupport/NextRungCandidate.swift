import Foundation

/// One real recipe the next-rung coach may recommend (DUT-1030). Built by the
/// caller from RecipeStore recipes on the Hero's Path; the coach never invents one.
public struct NextRungCandidate: Sendable, Equatable, Identifiable {
    public let recipeID: Int
    public let title: String
    /// 1 (easiest) ... 5 (hardest); clamped so scoring can trust it.
    public let difficulty: Int

    public var id: Int { recipeID }

    public init(recipeID: Int, title: String, difficulty: Int) {
        self.recipeID = recipeID
        self.title = title
        self.difficulty = min(5, max(1, difficulty))
    }
}
