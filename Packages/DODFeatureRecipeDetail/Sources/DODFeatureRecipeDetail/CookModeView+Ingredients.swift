import DODDesignSystem
import DODDomain
import DODSupport
import SwiftUI

// The Cook Mode ingredients drawer + its rows, moved out of `CookModeView.swift`
// (DUT-1392) so that file stays under the SwiftLint `file_length` cap.
extension CookModeView {

    // MARK: - Ingredients drawer (AC-7.2, AC-7.5)
    //
    // DUT-599 — the old bottom "Ingredients" pull tab is gone; ingredients now
    // open from the `carrot.fill` button in the transport's secondary row (see
    // `CookModePlayerControls`), wired via `openIngredients()` in
    // `CookModeView+Controls.swift`. The drawer itself is unchanged.

    var ingredientsDrawer: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DODSpacing.sm) {
                    ForEach(viewModel.recipe.ingredients) { ingredient in
                        ingredientRow(for: ingredient)
                    }
                }
                .padding(.horizontal, DODSpacing.md)
                .padding(.vertical, DODSpacing.md)
            }
            .navigationTitle("Ingredients")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            // Nav-consistency sweep: the drawer is a sheet, so it gets the app's
            // standard trailing "Done" dismissal (plus a drag indicator on the
            // sheet itself) instead of being a swipe-only dead end.
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        ingredientsDrawerVisible = false
                    }
                    .tint(DODColor.burntOrange)
                    .accessibilityIdentifier("cook-mode-ingredients-done")
                }
            }
        }
    }
}

// MARK: - Ingredients drawer row

extension CookModeView {
    /// One row in the ingredients drawer with the scaled `displayText`
    /// (US-31 / AC-31.4 carry-over into Cook Mode). Pulled into an
    /// extension so the type body stays under the SwiftLint length cap.
    @ViewBuilder
    private func ingredientRow(for ingredient: RecipeIngredient) -> some View {
        let scaled = FractionRenderer.scale(ingredient.text, by: ingredientScaleFactor)
        IngredientCheckRow(
            ingredient: ingredient,
            displayText: useMetricUnits ? IngredientMetricConverter.metric(scaled) : scaled,
            isChecked: viewModel.checkedIngredientIDs.contains(ingredient.id),
            onToggle: { viewModel.toggleIngredient(ingredient.id) }
        )
    }
}
