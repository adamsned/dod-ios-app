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
                // DUT-981 — post a guest's in-person praise as a public recipe
                // comment/review (host identity, guest attributed in the body).
                onPostGuestReaction: { quote, guest, rating in
                    await viewModel.submitGuestReaction(quote: quote, guestName: guest, rating: rating)
                },
                // T-912 / DUT-551 — forward the Heat Coach sheet builder so a
                // heat-related Cook Mode step can present Heat Coach OVER the
                // cover (a tab switch would be invisible under the full-screen
                // cover). Nil when the host doesn't wire hub routing.
                heatCoachSheet: cookModeSheets.heatCoach,
                askSheet: cookModeSheets.askAboutRecipe,
                // DUT-986 — first-cook-only training wheels (off once any cook is logged)
                isFirstCookEver: viewModel.isFirstCookEver
            )
        }
    }

    /// DUT-985 — the one-time first-cook expectation screen.
    @ViewBuilder
    var pepTalkCover: some View {
        if let recipe = viewModel.recipe {
            CookPepTalkView(
                recipe: recipe,
                onStart: {
                    viewModel.pepTalkStartRequested = true
                    viewModel.isPepTalkPresented = false
                },
                onCancel: { viewModel.isPepTalkPresented = false }
            )
        }
    }

    /// DUT-985 — single entry point for 'start Cook Mode'. Shows the pep talk
    /// first when the journal is empty, otherwise opens Cook Mode directly.
    func requestCookMode() {
        Task {
            await viewModel.didTapCookMode()
            if await viewModel.shouldShowPepTalk() {
                viewModel.isPepTalkPresented = true
            } else {
                isCookModePresented = true
            }
        }
    }

    /// Called from the pep talk cover's onDismiss: open Cook Mode only if the user tapped Start.
    func pepTalkDidDismiss() {
        guard viewModel.pepTalkStartRequested else { return }
        viewModel.pepTalkStartRequested = false
        isCookModePresented = true
    }
}
