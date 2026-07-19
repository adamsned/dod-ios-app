import Foundation

// DUT-1240 — split out of `RecipeDetailView.swift` to keep that file under
// the SwiftLint file-length cap.
extension RecipeDetailView {

    func handleLoadStateChange(_ newValue: RecipeDetailViewModel.LoadState) {
        if newValue == .unavailable {
            // Pop after a brief moment so the snackbar is visible.
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()
            }
        }
        // US-31 / AC-31.3: once the recipe is loaded, sync the stepper
        // default to the source `recipeYield` if we haven't already.
        if newValue == .ready {
            viewModel.resetServingsToSourceIfFirstLoad()
        }
        // US-10 / AC-10.1: if the deep link asked us to jump straight to
        // Cook Mode, do it the instant the recipe has instructions
        // populated. Same gating as the manual CTA (AC-7.1).
        guard newValue == .ready, pendingAutoCookMode else { return }
        guard let recipe = viewModel.recipe, !recipe.instructions.isEmpty else { return }
        pendingAutoCookMode = false
        Task { await viewModel.didTapCookMode() }
        isCookModePresented = true
        onAutoCookModeStarted?()  // DUT-1240 — intent fulfilled; let the host disarm.
    }
}
