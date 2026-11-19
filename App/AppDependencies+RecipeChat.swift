import DODFeatureFeed
import DODFeatureRecipeDetail
import SwiftUI

extension AppDependencies {

    /// DUT-1385 — the builder for Cook Mode's "Ask the Recipe" chat, or
    /// `nil` when no on-device model is usable right now, so Cook Mode shows no
    /// dead sparkle button (iOS 17-25, no Apple Intelligence, the simulator
    /// without `-DODFakeIntelligence`).
    func recipeChatSheetBuilder() -> CookModeSheets.AskRecipeBuilder? {
        let intelligence = intelligenceService()
        guard intelligence.isAvailable else { return nil }
        return { recipeTitle, recipeContext, suggestions in
            AnyView(
                RecipeChatSheet(
                    intelligence: intelligence,
                    recipeTitle: recipeTitle,
                    recipeContext: recipeContext,
                    suggestions: suggestions
                )
            )
        }
    }
}
