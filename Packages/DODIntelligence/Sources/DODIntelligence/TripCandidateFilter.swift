import DODDomain
import Foundation

public enum TripCandidateFilter {
    /// Recipes (not articles) that satisfy EVERY requested dietary tag (case-insensitive,
    /// and tolerant of a schema.org `Diet` suffix, e.g. "GlutenFreeDiet" matches "glutenfree").
    /// Capped at `limit` so the candidate list stays inside the 4096-token window.
    public static func candidates(
        from recipes: [Recipe],
        constraints: TripPlanConstraints,
        limit: Int = 12
    ) -> [Recipe] {
        let wanted = constraints.dietaryTags.map(normalize)
        let matches = recipes.filter { recipe in
            guard !recipe.isArticle else { return false }
            let have = Set(recipe.suitableForDiet.map(normalize))
            return wanted.allSatisfy(have.contains)
        }
        return Array(matches.prefix(max(0, limit)))
    }

    static func normalize(_ tag: String) -> String {
        var normalizedTag = tag.lowercased().filter { $0.isLetter }
        if normalizedTag.hasSuffix("diet") { normalizedTag.removeLast(4) }
        return normalizedTag
    }
}
