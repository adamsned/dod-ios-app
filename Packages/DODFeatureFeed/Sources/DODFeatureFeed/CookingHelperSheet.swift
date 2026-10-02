import DODDesignSystem
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

        /// The Cooking Tools "Ask Dutch Oven Daddy" helper.
        public static let general = Configuration(
            title: "Ask Dutch Oven Daddy",
            emptyTitle: "Ask Dutch Oven Daddy",
            emptyMessage: "Cast iron, Dutch ovens, techniques, recipe conversions, or attach a photo for help.",
            placeholder: "Ask about cooking or cast iron"
        )

        /// Cook Mode's chat about the one recipe being cooked.
        public static func recipe(_ recipeTitle: String) -> Configuration {
            Configuration(
                title: "Ask About This Recipe",
                emptyTitle: recipeTitle,
                emptyMessage: "Ask anything about this recipe while you cook: amounts, steps, timing, or what to do "
                    + "if something looks off.",
                placeholder: "Ask about this recipe"
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
                        CookingHelperThinkingView()
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
        VStack(spacing: DODSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(DODColor.accent)
            Text(configuration.emptyTitle)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
                .multilineTextAlignment(.center)
            Text(
                configuration.emptyMessage
            )
            .dodFont(DODType.body)
            .foregroundStyle(DODColor.labelSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DODSpacing.md)
        .accessibilityIdentifier("dod.cookingTools.helper.empty")
    }

    // MARK: - Input area (pinned above the keyboard)

    private var inputArea: some View {
        VStack(spacing: DODSpacing.xxs) {
            CookingHelperInputBar(viewModel: viewModel, placeholder: configuration.placeholder) { imageData in
                Task { await viewModel.ask(imageData: imageData) }
            }
            Text("Dutch Oven Daddy can make mistakes. Double-check important cooking info.")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DODSpacing.lg)
                .padding(.bottom, DODSpacing.xs)
                .frame(maxWidth: .infinity)
                .background(DODColor.surface)
        }
    }
}
