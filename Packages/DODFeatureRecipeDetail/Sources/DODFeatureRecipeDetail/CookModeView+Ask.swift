import DODDesignSystem
import DODDomain
import DODSupport
import SwiftUI

// DUT-1385 — Cook Mode's "Ask About This Recipe" chat. The chat view lives in
// `DODFeatureFeed` and arrives as the injected `askSheet` builder; this file
// supplies what it needs: the recipe title and the recipe as plain text, built
// at the moment the sheet opens so "this step" means the step on screen.
extension CookModeView {

    /// DUT-1392 — the "Ask About This Recipe" entry point: a plain orange label
    /// with sparkles directly under the recipe name (no pill), matching the
    /// Summarize link on recipe and article pages. Absent when no chat builder
    /// was injected (model unavailable), like the old top-bar button.
    @ViewBuilder
    var askAboutRecipeLink: some View {
        if askSheet != nil {
            Button {
                wakeControls()
                isAskPresented = true
            } label: {
                Label("Ask About This Recipe", systemImage: "sparkles")
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DODSpacing.md)
            .accessibilityIdentifier("cook-mode-ask")
            .accessibilityHint("Ask the on-device assistant about this recipe")
        }
    }

    /// The sheet body for `isAskPresented` (empty if no builder was injected).
    @ViewBuilder
    var askSheetContent: some View {
        if let askSheet {
            askSheet(viewModel.recipe.title, recipeChatContext)
        }
    }

    /// The open recipe as plain text, with ingredient amounts exactly as Cook
    /// Mode shows them (servings scale + metric preference applied).
    var recipeChatContext: String {
        let ingredientLines = viewModel.recipe.ingredients.map { ingredient in
            let scaled = FractionRenderer.scale(ingredient.text, by: ingredientScaleFactor)
            return useMetricUnits ? IngredientMetricConverter.metric(scaled) : scaled
        }
        return Self.recipeChatContext(
            recipe: viewModel.recipe,
            ingredientLines: ingredientLines,
            scaleFactor: ingredientScaleFactor,
            currentStepIndex: viewModel.currentStepIndex,
            isFinished: viewModel.isFinished
        )
    }

    /// Pure builder (unit-tested) for the recipe text sent with each question.
    nonisolated static func recipeChatContext(
        recipe: Recipe,
        ingredientLines: [String],
        scaleFactor: Double,
        currentStepIndex: Int,
        isFinished: Bool
    ) -> String {
        var lines = ["Recipe: \(recipe.title)"]
        if let servings = recipe.servings {
            let scaled = Int(exactly: (Double(servings) * scaleFactor).rounded()) ?? servings
            lines.append(scaleFactor == 1 ? "Servings: \(servings)" : "Servings: \(scaled) (scaled from \(servings))")
        }
        if let total = recipe.totalTime {
            lines.append("Total time: \(minutesText(total))")
        }
        if !ingredientLines.isEmpty {
            lines.append("\nIngredients:")
            lines += ingredientLines.map { "- \($0)" }
        }
        let steps = recipe.instructions.sorted { $0.step < $1.step }
        if !steps.isEmpty {
            lines.append("\nSteps:")
            lines += steps.enumerated().map { index, step in "\(index + 1). \(step.text)" }
            lines.append(
                isFinished
                    ? "\nThe cook has finished all the steps."
                    : "\nThe cook is currently on step \(min(currentStepIndex, steps.count - 1) + 1) of \(steps.count)."
            )
        }
        return lines.joined(separator: "\n")
    }

    /// "45 min", "2 hr", "1 hr 15 min".
    nonisolated static func minutesText(_ duration: Duration) -> String {
        let minutes = Int(duration.components.seconds / 60)
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours) hr \(remainder) min"
    }
}
