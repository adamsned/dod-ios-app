import DODDesignSystem
import SwiftUI

/// DUT-1862 — chat sheet for "Ask the Recipe" (grounded Q&A over the open recipe).
struct AskRecipeSheet: View {
    @Bindable var viewModel: RecipeDetailViewModel
    @State var draft = ""
    @State var isAsking = false
    let suggestions = ["Can I make this ahead?", "How do I double it?", "Can I substitute an ingredient?"]

    func send(_ text: String) {
        draft = ""
        isAsking = true
        Task {
            await viewModel.askRecipe(text)
            isAsking = false
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DODSpacing.xs) {
                ScrollView {
                    messageList
                }
                suggestionRow
                composerRow
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

extension AskRecipeSheet {
    var composerRow: some View {
        HStack(spacing: DODSpacing.xs) {
            TextField("Ask about this recipe", text: $draft)
                .textFieldStyle(.roundedBorder)
            Button("Send") { send(draft) }
                .disabled(isAsking || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(DODSpacing.md)
    }

    var suggestionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DODSpacing.xs) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) { send(suggestion) }
                        .buttonStyle(.bordered)
                        .disabled(isAsking)
                }
            }
            .padding(.horizontal, DODSpacing.md)
        }
    }
}
