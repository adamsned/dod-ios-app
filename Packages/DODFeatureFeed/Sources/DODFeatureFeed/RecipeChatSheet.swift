import DODIntelligence
import SwiftUI

/// DUT-1385 — Cook Mode's "Ask About This Recipe" chat: the same ChatGPT-style
/// conversation as the Ask Dutch Oven Daddy helper, scoped to the one recipe
/// being cooked. The recipe text rides along with every question so the
/// on-device model answers about THIS recipe.
///
/// Cook Mode lives in `DODFeatureRecipeDetail`, which can't import this package,
/// so the App injects a builder that returns this view (the same seam Heat Coach
/// uses). It owns its view model, and Done dismisses via the environment.
public struct RecipeChatSheet: View {

    @State private var viewModel: CookingHelperViewModel
    @Environment(\.dismiss) private var dismiss
    private let recipeTitle: String

    /// - Parameters:
    ///   - intelligence: The on-device AI seam (App-injected).
    ///   - recipeTitle: Shown as the empty-state title.
    ///   - recipeContext: The plain-text recipe (ingredients, steps, current
    ///     step) sent with each question.
    public init(intelligence: (any DODIntelligenceService)?, recipeTitle: String, recipeContext: String) {
        _viewModel = State(
            initialValue: CookingHelperViewModel(intelligence: intelligence, recipeContext: recipeContext)
        )
        self.recipeTitle = recipeTitle
    }

    public var body: some View {
        CookingHelperSheet(viewModel: viewModel, configuration: .recipe(recipeTitle)) {
            dismiss()
        }
    }
}
