import DODFeatureFeed
import SwiftUI

extension AppDependencies {

    /// DUT-1385 — the builder for Cook Mode's "Ask About This Recipe" chat, or
    /// `nil` when no on-device model is usable right now, so Cook Mode shows no
    /// dead sparkle button (iOS 17-25, no Apple Intelligence, the simulator
    /// without `-DODFakeIntelligence`).
    func recipeChatSheetBuilder() -> ((String, String) -> AnyView)? {
        let intelligence = intelligenceService()
        guard intelligence.isAvailable else { return nil }
        return { recipeTitle, recipeContext in
            AnyView(
                RecipeChatSheet(intelligence: intelligence, recipeTitle: recipeTitle, recipeContext: recipeContext)
            )
        }
    }
}
