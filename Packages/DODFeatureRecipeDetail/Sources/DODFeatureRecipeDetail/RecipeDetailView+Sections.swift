import DODDesignSystem
import DODDomain
import DODSupport
import SwiftUI

/// DUT-1903: one row of the detail ingredient list — either a section header
/// or an ingredient. Pure layout so it can be unit tested without a view.
enum IngredientListItem: Equatable {
    case header(String)
    case ingredient(RecipeIngredient)

    /// Interleave section headers before the first ingredient of each section.
    /// With no sections, returns the flat list unchanged.
    static func layout(
        ingredients: [RecipeIngredient],
        sections: [RecipeSection]
    ) -> [IngredientListItem] {
        var headerBefore: [UUID: String] = [:]
        for section in sections {
            if let first = section.ingredientIDs.first {
                headerBefore[first] = section.label
            }
        }
        return ingredients.flatMap { ingredient -> [IngredientListItem] in
            if let label = headerBefore[ingredient.id] {
                return [.header(label), .ingredient(ingredient)]
            }
            return [.ingredient(ingredient)]
        }
    }
}

extension RecipeDetailView {

    // MARK: - Ingredients + Instructions layout

    /// Ingredients + Instructions. Side by side in a wider centered band on a
    /// wide canvas (landscape iPad), stacked in the reading column otherwise.
    /// iPhone (compact) always stacks — byte-identical. T-804.
    @ViewBuilder
    func ingredientsInstructions(twoUp: Bool) -> some View {
        if twoUp {
            HStack(alignment: .top, spacing: DODSpacing.lg) {
                ingredientsSection
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .id(SectionAnchor.ingredients)
                // DUT-673 — the Cook Mode CTA now lives INSIDE the Instructions
                // section (right under its "Instructions" header, which carries
                // the `.instructions` scroll anchor), so "Jump to Instructions"
                // lands with the header on top and the CTA immediately visible.
                instructionsSection
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: DODContentWidth.wide)
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: DODSpacing.lg) {
                ingredientsSection.id(SectionAnchor.ingredients)
                instructionsSection
            }
            .readableContentColumn(horizontalSizeClass)
        }
    }

    // MARK: - Ingredients + Instructions

    // Extracted from `RecipeDetailView` (T-804) so the main struct's body stays
    // under the SwiftLint `type_body_length` cap after the iPad adaptive-layout
    // restructure. These are the two sections the landscape two-up lays side by
    // side; `readyBody` (in the main file) decides stacked vs. side-by-side.

    var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            // DUT-529: only emit the header when there's an actual list to show —
            // a `.ready` recipe with no ingredients otherwise renders a bare
            // "Ingredients" title with no rows beneath it.
            if let ingredients = viewModel.recipe?.ingredients, !ingredients.isEmpty {
                Text("Ingredients")
                    .dodFont(DODType.heading)
                    .foregroundStyle(DODColor.label)
                // US-31 / AC-31.4 + AC-31.5: scale at render time.
                // Source recipe `ingredient.text` stays untouched (AC-31.8).
                let factor = viewModel.servingsScaleFactor
                let items = IngredientListItem.layout(
                    ingredients: ingredients,
                    sections: viewModel.recipe?.sections ?? []
                )
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    switch item {
                    case .header(let label):
                        Text(label)
                            .dodFont(DODType.heading)
                            .foregroundStyle(DODColor.label)
                    case .ingredient(let ingredient):
                        let shown = displayIngredientText(ingredient.text, scaledBy: factor)
                        annotated(
                            IngredientCheckRow(
                                ingredient: ingredient,
                                displayText: shown,
                                isChecked: viewModel.checkedIngredientIDs.contains(ingredient.id),
                                onToggle: { viewModel.toggleIngredient(ingredient.id) }
                            ),
                            ingredient: ingredient,
                            displayText: shown
                        )
                    }
                }
            }
        }
        .padding(.horizontal, DODSpacing.md)
    }

    /// DUT-1014: applies the on-screen ingredient annotation once the recipe is
    /// loaded; passes the row through untouched while it is nil.
    @ViewBuilder
    private func annotated<V: View>(
        _ row: V,
        ingredient: RecipeIngredient,
        displayText: String
    ) -> some View {
        if let recipe = viewModel.recipe {
            row.ingredientAnnotation(
                .make(recipe: recipe, ingredient: ingredient, displayText: displayText)
            )
        } else {
            row
        }
    }

    /// The display string for one ingredient row: scale the source text for the
    /// chosen servings (US-31 / AC-31.4), then — when "Use Metric Units" is on
    /// (DUT-517) — convert the ALREADY-SCALED line to metric. Order matters: the
    /// converter reads the post-scale quantity, so `"1 cup" ×2 → "2 cups" →
    /// "480 ml"`. Non-convertible lines fall through unchanged.
    func displayIngredientText(_ text: String, scaledBy factor: Double) -> String {
        let scaled = FractionRenderer.scale(text, by: factor)
        return useMetricUnits ? IngredientMetricConverter.metric(scaled) : scaled
    }

    @ViewBuilder
    var instructionsSection: some View {
        // DUT-47 (temperature half): resolve the unit once per render. `nil`
        // ("Recipe default" / absent / malformed) leaves every step exactly
        // as written; otherwise each step's text is mapped through the
        // converter at display time (stored data untouched, AC-31.8-style).
        let temperatureUnit = TemperatureConverter.resolvedUnit(fromRawValue: temperatureUnitRaw)
        // DUT-529: gate on a non-empty list so a `.ready` recipe with no
        // instructions doesn't show a lone "Instructions" title.
        // The header + Cook Mode CTA + steps (and the iPad-only Apple Pencil
        // annotation layer) live in ``InstructionsSectionView``, which owns the
        // `@State` the header toggle and the canvas overlay share. On iPhone /
        // compact width the annotation affordance never renders (byte-identical).
        if let instructions = viewModel.recipe?.instructions, !instructions.isEmpty {
            InstructionsSectionView(
                instructions: instructions,
                displayText: { convertedStepText($0.text, to: temperatureUnit) },
                horizontalSizeClass: horizontalSizeClass,
                onCookMode: {
                    // DUT-985 — pep talk first on the very first cook; telemetry is sent inside.
                    requestCookMode()
                },
                load: { await viewModel.loadAnnotation() },
                save: { await viewModel.saveAnnotation($0) }
            )
        }
    }

    /// Apply the DUT-47 temperature conversion to one step's text, or return it
    /// unchanged when no unit is selected. Extracted so the `ForEach` body
    /// stays a single expression and the gating logic reads in one place.
    func convertedStepText(_ text: String, to unit: TemperatureUnit?) -> String {
        guard let unit else { return text }
        return TemperatureConverter.converting(text, to: unit)
    }
}
