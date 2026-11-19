import SwiftUI

/// The App-injected sheets Cook Mode can present over its full-screen cover.
/// Both surfaces live in `DODFeatureFeed`, which this package must not import, so
/// the App passes type-erased builders (the T-912 Heat Coach seam, extended for
/// DUT-1385). Grouped in one value so `RecipeDetailView` (at the SwiftLint
/// length cap) carries a single property for them.
public struct CookModeSheets {

    /// T-912 / DUT-551 — the Heat Coach sheet for heat-related steps. `nil`
    /// hides the shortcut.
    public let heatCoach: (() -> AnyView)?

    /// DUT-1385 / DUT-2895 — builds the "Ask the Recipe" chat from the recipe
    /// title, its plain-text context, and the suggested-question chips.
    public typealias AskRecipeBuilder =
        (_ recipeTitle: String, _ recipeContext: String, _ suggestions: [String]) -> AnyView

    /// DUT-1385 — the "Ask the Recipe" chat over Cook Mode. `nil` (no usable
    /// on-device model) hides the Cook Mode sparkle link.
    public let askAboutRecipe: AskRecipeBuilder?

    public init(
        heatCoach: (() -> AnyView)? = nil,
        askAboutRecipe: AskRecipeBuilder? = nil
    ) {
        self.heatCoach = heatCoach
        self.askAboutRecipe = askAboutRecipe
    }
}
