import DODDesignSystem
import SwiftUI

/// DUT-246 — the "Open the recipe" action for ``FirstCookoutView``.
///
/// The old shape (`openURL(url); dismiss()`) dismissed the celebratory sheet
/// synchronously while the app shell's link resolve was still in flight,
/// leaving a blank dead interval — and on a nil resolve (offline, or the
/// campfire slug that maps to a WP page) the user was silently bounced to
/// Safari with the sheet already gone. Now the sheet stays up (with a busy
/// state on the button) until the shell's awaitable ``RecipeLinkOpener``
/// reports the outcome: dismiss only when in-app navigation actually
/// happened; on a browser fallback the sheet stays put so the flow is still
/// there when the user returns.
extension FirstCookoutView {

    var recipeButton: some View {
        Button {
            openRecipe()
        } label: {
            if isOpeningRecipe {
                // Keep the label so the button doesn't collapse; the spinner
                // communicates the in-flight resolve.
                HStack(spacing: DODSpacing.xs) {
                    ProgressView().tint(DODColor.cream)
                    Text(recipeLinkLabel)
                }
            } else {
                Text(recipeLinkLabel)
            }
        }
        .dodProminentButton()
        .tint(DODColor.burntOrange)
        .disabled(isOpeningRecipe)
        .padding(.top, DODSpacing.xs)
    }

    private func openRecipe() {
        guard let url = URL(string: "\(recipeBaseURL)/\(cookout.recipeSlug)/") else { return }
        guard let recipeLinkOpener else {
            // Unwired host (previews / tests): the legacy fire-and-forget path.
            openURL(url)
            dismiss()
            return
        }
        guard !isOpeningRecipe else { return }
        isOpeningRecipe = true
        Task {
            let navigatedInApp = await recipeLinkOpener.open(url)
            isOpeningRecipe = false
            // Dismiss only when the recipe actually opened in-app underneath
            // us. A browser fallback leaves the sheet up so the guided flow is
            // still here when the user comes back.
            if navigatedInApp { dismiss() }
        }
    }
}
