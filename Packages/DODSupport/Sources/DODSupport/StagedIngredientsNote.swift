import DODDomain
import Foundation

/// DUT-1002: packing note splitting ingredients into cooler, prepped-dry and raw. A future Bring List can consume it.
public enum StagedIngredientsNote {
    public struct Note: Sendable, Equatable {
        public let cooler: [String]
        public let preppedDry: [String]
        public let raw: [String]
    }

    static let perishable = [
        "beef", "pork", "chicken", "sausage", "cheese", "ricotta", "mozzarella",
        "sauce", "milk", "cream", "egg", "butter",
    ]

    /// An ingredient is staged when any kitchen-prep step mentions one of its key words (longer than 3 letters).
    public static func build(from recipe: Recipe) -> Note {
        let homeText = SplitCookStageClassifier.partition(recipe.instructions).home
            .map { $0.text.lowercased() }
            .joined(separator: " ")
        var cooler: [String] = []
        var dry: [String] = []
        var raw: [String] = []
        for ingredient in recipe.ingredients {
            let line = ingredient.text.lowercased()
            let words = line.split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count > 3 }
            let staged = words.contains { homeText.contains($0) }
            if !staged {
                raw.append(ingredient.text)
            } else if perishable.contains(where: { line.contains($0) }) {
                cooler.append(ingredient.text)
            } else {
                dry.append(ingredient.text)
            }
        }
        return Note(cooler: cooler, preppedDry: dry, raw: raw)
    }
}
