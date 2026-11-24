import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-1862 — chat sheet for "Ask the Recipe" (grounded Q&A over the open recipe).
///
/// DUT-2893 — rebuilt on the shared DODDesignSystem chat pieces so it looks
/// exactly like "Ask Dutch Oven Daddy": sparkles empty state, orange user
/// bubbles, assistant cards, a "Thinking…" row, the rounded field with the round
/// send button, the disclaimer, and Done. The chips are built from the recipe
/// (``RecipeDetailViewModel/askRecipeSuggestions``) and drop away once asked.
struct AskRecipeSheet: View {
    @Bindable var viewModel: RecipeDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State var draft = ""
    @State var isAsking = false

    private let bottomAnchor = "dod.askRecipe.bottom"

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAsking else { return }
        draft = ""
        isAsking = true
        Task {
            await viewModel.askRecipe(trimmed)
            isAsking = false
        }
    }

    var body: some View {
        NavigationStack {
            conversation
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DODColor.surface)
                .navigationTitle("Ask the Recipe")
                #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .tint(DODColor.accent)
                            .accessibilityIdentifier("dod.detail.askRecipe.done")
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { inputArea }
        }
        .accessibilityIdentifier("dod.detail.askRecipe.sheet")
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DODSpacing.md) {
                    if viewModel.askMessages.isEmpty && !isAsking {
                        DODChatEmptyState(
                            title: viewModel.recipe?.title ?? "Ask the Recipe",
                            message: "Ask anything about this recipe: swaps, scaling, timing, or what to do "
                                + "if something looks off."
                        )
                        .padding(.top, DODSpacing.xl)
                    }
                    ForEach(viewModel.askMessages) { message in
                        DODChatMessageRow(isUser: message.role == .user, text: message.text)
                            .id(message.id)
                    }
                    if isAsking {
                        DODChatThinkingRow()
                    }
                    Color.clear.frame(height: 1).id(bottomAnchor)
                }
                .padding(DODSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.askMessages.count) {
                withAnimation { proxy.scrollTo(bottomAnchor, anchor: .bottom) }
            }
            .onChange(of: isAsking) {
                withAnimation { proxy.scrollTo(bottomAnchor, anchor: .bottom) }
            }
        }
    }

    private var inputArea: some View {
        VStack(spacing: DODSpacing.xxs) {
            DODChatSuggestionChips(suggestions: remainingSuggestions, isDisabled: isAsking) { send($0) }
                .padding(.top, DODSpacing.xs)
            DODChatField(
                placeholder: "Ask about this recipe",
                text: $draft,
                canSend: !isAsking && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                fieldIdentifier: "dod.detail.askRecipe.field",
                sendIdentifier: "dod.detail.askRecipe.send"
            ) { send(draft) }
            .padding(.horizontal, DODSpacing.md)
            .padding(.vertical, DODSpacing.xs)
            DODChatDisclaimer()
        }
        .background(DODColor.surface)
    }

    private var remainingSuggestions: [String] {
        ChatSuggestions.remaining(
            viewModel.askRecipeSuggestions,
            askedTexts: viewModel.askMessages.filter { $0.role == .user }.map(\.text)
        )
    }
}
