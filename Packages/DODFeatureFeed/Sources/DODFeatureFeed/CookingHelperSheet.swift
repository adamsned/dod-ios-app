import DODDesignSystem
import DODSupport
import SwiftUI

/// T-934 (US-54 / DUT-1382) — the "Ask Dutch Oven Daddy" sheet, redesigned as a
/// ChatGPT-style conversation: answers stack in a scrolling transcript and the
/// input bar is pinned above the keyboard (via `safeAreaInset`) with the send
/// button inside it and, where the model supports vision, a photo-attach button.
///
/// The transcript rows live in `CookingHelperConversation.swift` and the input
/// bar in `CookingHelperInputBar.swift` to keep this file under the 400-line cap.
public struct CookingHelperSheet: View {

    @Bindable var viewModel: CookingHelperViewModel
    let onDone: () -> Void
    let configuration: Configuration

    /// DUT-1385 — the copy that differs between the general helper and Cook
    /// Mode's recipe-scoped chat.
    public struct Configuration: Sendable {
        public let title: String
        public let emptyTitle: String
        public let emptyMessage: String
        public let placeholder: String
        /// DUT-2893 — suggested-question chips above the input (asked ones drop away).
        public let suggestions: [String]

        /// The Cooking Tools "Ask Dutch Oven Daddy" helper. DUT-2893 — chips are
        /// a daily-rotating set of cast iron questions.
        public static var general: Configuration {
            Configuration(
                title: "Ask Dutch Oven Daddy",
                emptyTitle: "Ask Dutch Oven Daddy",
                emptyMessage: "Cast iron, Dutch ovens, techniques, recipe conversions, or attach a photo for help.",
                placeholder: "Ask about cooking or cast iron",
                suggestions: ChatSuggestions.general(dayKey: ChatSuggestions.dayKey(for: Date()))
            )
        }

        /// Cook Mode's chat about the one recipe being cooked.
        public static func recipe(_ recipeTitle: String, suggestions: [String] = []) -> Configuration {
            Configuration(
                title: "Ask About This Recipe",
                emptyTitle: recipeTitle,
                emptyMessage: "Ask anything about this recipe while you cook: amounts, steps, timing, or what to do "
                    + "if something looks off.",
                placeholder: "Ask about this recipe",
                suggestions: suggestions
            )
        }
    }

    public init(
        viewModel: CookingHelperViewModel,
        configuration: Configuration = .general,
        onDone: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.configuration = configuration
        self.onDone = onDone
    }

    private let bottomAnchor = "dod.cookingHelper.bottom"

    public var body: some View {
        NavigationStack {
            conversation
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DODColor.surface)
                .navigationTitle(configuration.title)
                #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onDone() }
                            .tint(DODColor.accent)
                            .accessibilityIdentifier("dod.cookingTools.helper.done")
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    inputArea
                }
        }
        .accessibilityIdentifier("dod.cookingTools.helper.sheet")
    }

    // MARK: - Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DODSpacing.md) {
                    if viewModel.turns.isEmpty && !viewModel.isResponding {
                        emptyState
                            .padding(.top, DODSpacing.xl)
                    }
                    ForEach(viewModel.turns) { turn in
                        CookingHelperTurnView(turn: turn)
                            .id(turn.id)
                    }
                    if viewModel.isResponding {
                        DODChatThinkingRow()
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchor)
                }
                .padding(DODSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.turns.count) {
                withAnimation { proxy.scrollTo(bottomAnchor, anchor: .bottom) }
            }
            .onChange(of: viewModel.isResponding) {
                withAnimation { proxy.scrollTo(bottomAnchor, anchor: .bottom) }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        DODChatEmptyState(title: configuration.emptyTitle, message: configuration.emptyMessage)
            .accessibilityIdentifier("dod.cookingTools.helper.empty")
    }

    // MARK: - Input area (pinned above the keyboard)

    private var inputArea: some View {
        VStack(spacing: DODSpacing.xxs) {
            DODChatSuggestionChips(
                suggestions: remainingSuggestions,
                isDisabled: viewModel.isResponding
            ) { suggestion in
                viewModel.question = suggestion
                Task { await viewModel.ask(imageData: nil) }
            }
            .padding(.top, DODSpacing.xs)
            CookingHelperInputBar(viewModel: viewModel, placeholder: configuration.placeholder) { imageData in
                Task { await viewModel.ask(imageData: imageData) }
            }
            DODChatDisclaimer()
        }
        .background(DODColor.surface)
    }

    /// DUT-2893 — the chips not yet asked in this conversation.
    private var remainingSuggestions: [String] {
        ChatSuggestions.remaining(
            configuration.suggestions,
            askedTexts: viewModel.turns.filter { $0.role == .user }.map(\.text)
        )
    }
}
