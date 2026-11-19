import DODDomain
import DODFeatureProfile
import Foundation

/// A simple banner structure for displaying roster warnings and portion messages
public struct RosterHeadsUpBanner: Equatable {
    public let warnings: [String]
    public let portionMessage: String?

    public init(warnings: [String], portionMessage: String?) {
        self.warnings = warnings
        self.portionMessage = portionMessage
    }

    public var isEmpty: Bool {
        warnings.isEmpty && portionMessage == nil
    }
}

extension RecipeDetailViewModel {
    /// DUT-993: plain-language heads-up lines, e.g. "Contains dairy - flagged for Emma". Reminder, not medical-grade.
    nonisolated static func rosterHeadsUps(recipe: Recipe, members: [HouseholdMember]) -> [String] {
        let texts = recipe.ingredients.map(\.text)
        var lines: [String] = []
        for member in members where !member.flags.isEmpty {
            let hits = HouseholdDietMatcher.triggeredFlags(
                flags: member.flags,
                ingredientTexts: texts,
                diets: recipe.suitableForDiet
            )
            guard !hits.isEmpty else { continue }
            let names = hits.map(\.displayName).sorted().joined(separator: ", ")
            lines.append("Contains \(names) - flagged for \(member.name)")
        }
        return lines
    }

    nonisolated static func rosterPortionMessage(recipe: Recipe, members: [HouseholdMember]) -> String? {
        HouseholdPortionCheck.message(
            for: HouseholdPortionCheck.verdict(members: members, servings: recipe.servings)
        )
    }
}
