import SwiftUI

// The Cook Mode full-screen cover content, split out of `RecipeDetailView.swift`
// to keep that file under the SwiftLint 400-line `file_length` cap (mirrors the
// `RecipeDetailView+Toolbar` split).

extension RecipeDetailView {

    @ViewBuilder
    var cookModeCover: some View {
        if let recipe = viewModel.recipe, !recipe.instructions.isEmpty {
            CookModeView(
                recipe: recipe,
                initialCheckedIngredients: viewModel.checkedIngredientIDs,
                ingredientScaleFactor: viewModel.servingsScaleFactor,
                onClose: { updatedChecks in
                    viewModel.mergeIngredientChecks(updatedChecks)
                    isCookModePresented = false
                },
                // DUT-326 — persist a Cook Mode "log this cook" to the journal
                // store. The sheet has already saved the photo + assembled the
                // entry; the VM writes it through the dependency seam.
                onLogCook: { entry in
                    Task { await viewModel.logCook(entry) }
                },
                // T-912 / DUT-551 — forward the Heat Coach sheet builder so a
                // heat-related Cook Mode step can present Heat Coach OVER the
                // cover (a tab switch would be invisible under the full-screen
                // cover). Nil when the host doesn't wire hub routing.
                heatCoachSheet: heatCoachSheet
            )
        }
    }
}
