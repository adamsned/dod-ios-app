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

    public init(viewModel: CookingHelperViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    private let bottomAnchor = "dod.cookingHelper.bottom"

    public var body: some View {
        NavigationStack {
            conversation
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DODColor.surface)
                .navigationTitle("Ask Dutch Oven Daddy")
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
            Text("Ask Dutch Oven Daddy")
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
                .multilineTextAlignment(.center)
            Text(
                "Cast iron, Dutch ovens, techniques, recipe conversions, or attach a photo of your pan or dish for a hand."
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
            CookingHelperInputBar(viewModel: viewModel) { imageData in
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
