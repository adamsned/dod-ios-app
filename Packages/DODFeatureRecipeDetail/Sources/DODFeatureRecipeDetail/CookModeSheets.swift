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

    /// DUT-1385 — the "Ask About This Recipe" chat, built from the recipe title
    /// and its plain-text context. `nil` (no usable on-device model) hides the
    /// Cook Mode sparkle button.
    public let askAboutRecipe: ((_ recipeTitle: String, _ recipeContext: String) -> AnyView)?

    public init(
        heatCoach: (() -> AnyView)? = nil,
        askAboutRecipe: ((_ recipeTitle: String, _ recipeContext: String) -> AnyView)? = nil
    ) {
        self.heatCoach = heatCoach
        self.askAboutRecipe = askAboutRecipe
    }
}
