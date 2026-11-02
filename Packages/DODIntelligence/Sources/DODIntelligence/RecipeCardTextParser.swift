import DODDomain
import Foundation

/// DUT-1004: turns raw OCR text from a family recipe card into a `FamilyRecipe`.
/// Pure and deterministic. The first non-heading line is the title; lines under
/// an "Ingredients" heading are ingredients; lines under a
/// directions-style heading are steps.
public enum RecipeCardTextParser {

    private static let stepHeadings: Set<String> = [
        "directions", "instructions", "method", "steps", "preparation",
    ]

    private enum Section { case title, ingredients, instructions }

    /// Returns `nil` when neither an ingredient nor a step line was found.
    public static func parse(_ raw: String, now: Date = Date()) -> FamilyRecipe? {
        var section = Section.title
        var title: String?
        var ingredientLines: [String] = []
        var stepLines: [String] = []

        let lines = raw.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for line in lines {
            let key = line.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ": "))
            if key == "ingredients" {
                section = .ingredients
                continue
            }
            if stepHeadings.contains(key) {
                section = .instructions
                continue
            }
            switch section {
            case .title:
                if title == nil { title = line }
            case .ingredients:
                ingredientLines.append(stripMarker(line))
            case .instructions:
                stepLines.append(stripMarker(line))
            }
        }

        guard !ingredientLines.isEmpty || !stepLines.isEmpty else { return nil }
        return FamilyRecipe(
            title: title ?? "Family Recipe",
            ingredients: RecipeIngredient.list(from: ingredientLines),
            instructions: stepLines.enumerated().map {
                RecipeInstruction(step: $0.offset + 1, text: $0.element)
            },
            createdAt: now
        )
    }

    /// Drops a leading bullet (`-`, `•`, `*`, `·`) or number (`1.` / `1)`).
    static func stripMarker(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"^\s*(?:[-•*·]|\d+[.)])\s+"#,
            with: "",
            options: .regularExpression
        )
    }
}
