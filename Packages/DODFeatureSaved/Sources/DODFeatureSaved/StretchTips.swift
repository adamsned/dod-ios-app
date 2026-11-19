import DODDomain
import Foundation

/// "Stretch this recipe" tips (DUT-997).
public enum StretchTips {

    public struct Tip: Equatable, Sendable, Identifiable {
        public var id: String { text }
        public let text: String

        public init(text: String) {
            self.text = text
        }
    }

    /// Tips for `recipe` when feeding `headcount`. Empty unless headcount > the
    /// recipe's base servings (CrowdBudgetEstimator.baseServings(for:)).
    public static func tips(for recipe: Recipe, headcount: Int) -> [Tip] {
        guard headcount > CrowdBudgetEstimator.baseServings(for: recipe) else { return [] }
        let text = recipe.ingredients.map { $0.text.lowercased() }.joined(separator: " ")
        var result: [Tip] = []
        let hasBulk = text.contains("rice") || text.contains("bean")
        if !hasBulk {
            result.append(Tip(text: "Bulk it up: stir in a pot of rice or a can or two of beans."))
        }
        let pricey = ["beef", "steak", "chuck", "lamb"]
        if pricey.contains(where: { text.contains($0) }) {
            result.append(Tip(text: "Cheaper protein swap: use chicken thighs or sausage in place of beef."))
        }
        if text.contains("chicken breast") {
            result.append(Tip(text: "Cheaper protein swap: bone-in chicken thighs cost less per pound."))
        }
        return result
    }
}
