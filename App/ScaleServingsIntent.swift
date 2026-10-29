import AppIntents
import DODSupport
import Foundation

/// DUT-1016 - "Scale this to serve twelve in Dutch Oven Daddy". Mutating
/// action: asks the open recipe screen to move its servings stepper.
struct ScaleServingsIntent: AppIntent {

    static let title: LocalizedStringResource = "Scale Servings"
    static let description = IntentDescription("Scales a recipe to serve a different number of people.")

    @Parameter(title: "Recipe")
    var recipe: RecipeEntity?

    // DUT-1016: swap to ValueRepresentation-backed count on iOS 27 SDK
    @Parameter(title: "Servings", default: 4, requestValueDialog: "How many servings?")
    var servings: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Scale \(\.$recipe) to serve \(\.$servings)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let target = OnscreenRecipe.resolve(recipe) else {
            throw $recipe.needsValueError("Which recipe do you want to scale?")
        }
        let applied = Self.clamp(servings)
        ServingsScaleRequest.post(recipeID: target.id, servings: applied)
        return .result(dialog: IntentDialog(stringLiteral: Self.dialogText(servings: applied, title: target.title)))
    }

    /// Mirrors `RecipeDetailViewModel.userServingsRange` (1...24).
    static func clamp(_ count: Int) -> Int { min(max(count, 1), 24) }

    /// Pure dialog copy (unit-tested). No em dashes.
    static func dialogText(servings: Int, title: String) -> String {
        servings == 1 ? "Scaled \(title) to serve 1." : "Scaled \(title) to serve \(servings)."
    }
}
