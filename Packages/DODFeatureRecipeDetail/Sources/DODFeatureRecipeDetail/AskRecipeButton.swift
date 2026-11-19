import DODDesignSystem
import SwiftUI

/// DUT-1862 — the labeled "Ask the Recipe" link under the recipe header. Mirrors
/// `SummarizeButton`; the caller only shows it when
/// `viewModel.isAskRecipeAvailable` (absent, never disabled).
struct AskRecipeButton: View {
    let viewModel: RecipeDetailViewModel
    @State private var showAsk = false

    var body: some View {
        Button {
            showAsk = true
        } label: {
            Label("Ask the Recipe", systemImage: "bubble.left.and.text.bubble.right")
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.accent)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dod.detail.askRecipe.button")
        .accessibilityHint("Ask a question about this recipe on your device")
        .sheet(isPresented: $showAsk) {
            AskRecipeSheet(viewModel: viewModel)
        }
    }
}
