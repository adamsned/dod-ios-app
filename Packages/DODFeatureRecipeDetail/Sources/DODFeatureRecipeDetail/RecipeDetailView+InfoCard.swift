import DODDomain
import SwiftUI

/// DUT-572 / CL-312 — the resolved ``RecipeInfoCard/Model`` builder and its
/// small formatting helpers, split into this `+`-suffixed extension so
/// `RecipeDetailView.swift` stays under the SwiftLint file-length cap.
extension RecipeDetailView {

    /// DUT-572 / CL-312 — resolved ``RecipeInfoCard/Model`` built from the
    /// loaded recipe: times pre-formatted, arrays joined with ", ", diet values
    /// prettified from schema.org URLs. Every field is optional — the card
    /// renders only the non-nil rows / cells and no-ops when everything is nil.
    var infoCardModel: RecipeInfoCard.Model {
        let recipe = viewModel.recipe
        return RecipeInfoCard.Model(
            prepTime: recipe?.prepTime.map { format(duration: $0) },
            cookTime: recipe?.cookTime.map { format(duration: $0) },
            totalTime: recipe?.totalTime.map { format(duration: $0) },
            course: joinedOrNil(recipe?.recipeCategory),
            cuisine: joinedOrNil(recipe?.recipeCuisine),
            diet: joinedOrNil(recipe?.suitableForDiet.map(RecipeInfoCard.prettifyDiet)),
            servings: recipe?.servings.map { "\($0)" },
            calories: recipe?.nutrition?.calories,
            author: recipe?.author
        )
    }

    /// Join a non-empty `[String]` with ", "; `nil` for a missing or empty
    /// array so the info card cell hides.
    func joinedOrNil(_ values: [String]?) -> String? {
        guard let values, !values.isEmpty else { return nil }
        return values.joined(separator: ", ")
    }

    /// Format a `Duration` as a compact human string ("25 min", "1 hr",
    /// "1h 30m") for the info card's time rows.
    func format(duration: Duration) -> String {
        let seconds = Int(duration.components.seconds)
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours)h \(remainder)m"
    }
}
