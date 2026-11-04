import Foundation

/// DUT-996 — low-pressure pre-cook prompt for a picky eater.
public enum OneBitePrompt {

    public struct Prompt: Equatable, Sendable {
        public let goal: String
        public let pairing: String
    }

    public static func make(dinerName: String, recipeTitle: String) -> Prompt {
        let goal = "Goal for \(dinerName): just one bite. No pressure, and no clean-plate rule."
        return Prompt(goal: goal, pairing: pairing(forRecipeTitle: recipeTitle))
    }

    static func pairing(forRecipeTitle title: String) -> String {
        let lowercaseTitle = title.lowercased()
        if lowercaseTitle.contains("chili") || lowercaseTitle.contains("stew") || lowercaseTitle.contains("soup") {
            return "Serve a small cup on the side with cornbread or crackers they already like."
        }
        if lowercaseTitle.contains("chicken") || lowercaseTitle.contains("pork") || lowercaseTitle.contains("beef") {
            return "Plate the meat separate from the sides, next to a familiar starch like rice or buttered noodles."
        }
        if lowercaseTitle.contains("cobbler") || lowercaseTitle.contains("cake") || lowercaseTitle.contains("bread") {
            return "Offer a tiny first slice beside something familiar, like ice cream or butter."
        }
        return "Put one small bite of it on the plate next to a food they already love."
    }
}
