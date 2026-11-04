import DODDomain
import Foundation

/// DUT-1002: keyword-based default tagging for split cooks. An explicit `stage` always wins.
public enum SplitCookStageClassifier {
    static let homeKeywords = [
        "chop", "dice", "slice", "mince", "brown", "cook the meat", "make the sauce",
        "assemble", "layer", "marinate", "mix the", "prep", "boil", "refrigerate", "chill",
    ]
    static let campKeywords = [
        "coals", "charcoal", "campfire", "lid", "dutch oven", "bake", "serve", "simmer", "sear",
    ]

    /// Camp keywords win ties, because oven or fire words mean the step happens at the site.
    public static func stage(for instruction: RecipeInstruction) -> CookStage {
        if let explicit = instruction.stage { return explicit }
        let text = instruction.text.lowercased()
        if campKeywords.contains(where: { text.contains($0) }) { return .campfireFinish }
        if homeKeywords.contains(where: { text.contains($0) }) { return .kitchenPrep }
        return .campfireFinish
    }

    public static func partition(
        _ instructions: [RecipeInstruction]
    ) -> (home: [RecipeInstruction], camp: [RecipeInstruction]) {
        var home: [RecipeInstruction] = []
        var camp: [RecipeInstruction] = []
        for step in instructions {
            if stage(for: step) == .kitchenPrep { home.append(step) } else { camp.append(step) }
        }
        return (home, camp)
    }
}
