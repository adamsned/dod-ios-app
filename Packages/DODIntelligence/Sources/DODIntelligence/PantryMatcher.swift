import DODDomain
import Foundation

/// One recipe scored against what is on hand (DUT-1009).
public struct PantryMatch: Sendable, Equatable, Identifiable {
    public var id: Int { recipeID }
    public let recipeID: Int
    public let title: String
    /// Ingredient lines that contain a pantry item.
    public let matchedLines: [String]
    /// Ingredient lines with no pantry item.
    public let missingLines: [String]
    /// matched / total, 0...1.
    public let coverage: Double
}

public enum PantryMatcher {
    /// Lowercased, trimmed, de-duplicated, non-empty.
    public static func normalize(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return
            names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Rank recipes (kind == .recipe, at least one ingredient) by coverage,
    /// then fewest missing lines, then title. Drops recipes with zero matches.
    public static func rank(recipes: [Recipe], pantry: [String], limit: Int = 10) -> [PantryMatch] {
        let items = normalize(pantry)
        guard !items.isEmpty else { return [] }
        let matches: [PantryMatch] = recipes.compactMap { recipe in
            guard recipe.kind == .recipe, !recipe.ingredients.isEmpty else { return nil }
            var matched: [String] = []
            var missing: [String] = []
            for line in recipe.ingredients.map(\.text) {
                let lower = line.lowercased()
                if items.contains(where: { lower.contains($0) }) { matched.append(line) } else { missing.append(line) }
            }
            guard !matched.isEmpty else { return nil }
            let total = matched.count + missing.count
            return PantryMatch(
                recipeID: recipe.id,
                title: recipe.title,
                matchedLines: matched,
                missingLines: missing,
                coverage: Double(matched.count) / Double(total)
            )
        }
        return Array(
            matches.sorted {
                if $0.coverage != $1.coverage { return $0.coverage > $1.coverage }
                if $0.missingLines.count != $1.missingLines.count {
                    return $0.missingLines.count < $1.missingLines.count
                }
                return $0.title < $1.title
            }
            .prefix(limit)
        )
    }
}
