import DODDesignSystem
import SwiftUI

/// DUT-1862 — chat sheet for "Ask the Recipe" (grounded Q&A over the open recipe).
struct AskRecipeSheet: View {
    @Bindable var viewModel: RecipeDetailViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                messageList
            }
            .navigationTitle("Ask the Recipe")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    var messageList: some View {
        LazyVStack(alignment: .leading, spacing: DODSpacing.xs) {
            ForEach(viewModel.askMessages) { message in
                Text(message.text)
                    .padding(DODSpacing.xs)
                    .frame(
                        maxWidth: .infinity,
                        alignment: message.role == .user ? .trailing : .leading
                    )
            }
        }
        .padding(.horizontal, DODSpacing.md)
    }
}
