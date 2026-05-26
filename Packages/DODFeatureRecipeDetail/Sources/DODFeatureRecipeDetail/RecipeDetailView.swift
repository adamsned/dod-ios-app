import DODDesignSystem
import DODDomain
import SwiftUI

/// Recipe detail screen. Header (AC-4.1) + ingredients (AC-4.2) + instructions
/// (AC-4.3) + optional video (AC-4.4, AC-4.5) + related (AC-4.6) +
/// save (AC-4.7) + share (AC-4.8). VoiceOver labels (AC-4.10).
/// Offline-aware (AC-4.9, AC-5.4, AC-5.5).
/// Cook Now CTA presents Cook Mode (US-7).
public struct RecipeDetailView: View {

    private enum SectionAnchor: Hashable {
        case ingredients
        case instructions
    }

    @State private var viewModel: RecipeDetailViewModel
    @State private var isOfflineSnapshot: Bool = false
    @State private var isCookModePresented: Bool = false
    /// True when the screen was entered via the StartCookModeIntent deep
    /// link (US-10). We watch the load state and flip the cover open as
    /// soon as the recipe has instructions to render. Resets to false
    /// after firing so a manual exit + re-entry behaves normally.
    @State private var pendingAutoCookMode: Bool
    @Environment(\.dismiss) private var dismiss
    public let onSelectRelated: (RecipeListItem) -> Void

    public init(
        viewModel: RecipeDetailViewModel,
        onSelectRelated: @escaping (RecipeListItem) -> Void,
        autoStartCookMode: Bool = false
    ) {
        _viewModel = State(initialValue: viewModel)
        _pendingAutoCookMode = State(initialValue: autoStartCookMode)
        self.onSelectRelated = onSelectRelated
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            content
            snackbar
        }
        .background(DODColor.surface)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarItems }
        // Note: T-302 originally added a sticky `RecipeDetailFloatingActions`
        // overlay anchored to `.bottomTrailing` here. Removed by T-410 /
        // CL-42 — the nav-bar Save + Share (AC-4.7 + AC-4.8) are the
        // single in-recipe affordance for both actions. See US-26 / AC-26.1.
        .sensoryFeedback(.success, trigger: viewModel.isSaved)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.checkedIngredientIDs.count)
        #if os(iOS)
        .fullScreenCover(isPresented: $isCookModePresented) {
            cookModeCover
        }
        #else
        .sheet(isPresented: $isCookModePresented) {
            cookModeCover
        }
        #endif
        .task {
            await viewModel.onAppear()
            isOfflineSnapshot = await viewModel.isOffline
        }
        .onChange(of: viewModel.loadState) { _, newValue in
            handleLoadStateChange(newValue)
        }
    }

    @ViewBuilder
    private var cookModeCover: some View {
        if let recipe = viewModel.recipe, !recipe.instructions.isEmpty {
            CookModeView(
                recipe: recipe,
                initialCheckedIngredients: viewModel.checkedIngredientIDs,
                onClose: { updatedChecks in
                    viewModel.mergeIngredientChecks(updatedChecks)
                    isCookModePresented = false
                }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loadingDetail:
            loadingSkeleton
        case .unavailable:
            EmptyState(
                systemImage: "exclamationmark.triangle",
                title: "Recipe unavailable",
                message: "This recipe can't be displayed right now."
            )
        case .ready:
            readyBody
        }
    }

    private var loadingSkeleton: some View {
        ScrollView {
            VStack(spacing: DODSpacing.md) {
                LoadingSkeleton(cornerRadius: 0).frame(height: 280)
                LoadingSkeleton().frame(height: 24).padding(.horizontal, DODSpacing.md)
                LoadingSkeleton().frame(height: 16).padding(.horizontal, DODSpacing.lg)
                LoadingSkeleton().frame(height: 16).padding(.horizontal, DODSpacing.lg)
            }
        }
        .accessibilityLabel("Loading recipe")
    }

    private var readyBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DODSpacing.lg) {
                    RecipeDetailHero(
                        url: viewModel.recipe?.heroImageLargeURL ?? viewModel.listItem.heroImage,
                        title: viewModel.listItem.title
                    )
                    RecipeDetailMetaPills(items: metaPillItems)
                    cookNowSection
                    excerptText
                    RecipeDetailQuickJump(items: quickJumpItems(proxy: proxy))
                    if let video = viewModel.recipe?.video {
                        RecipeDetailVideoSection(video: video, isOfflineSnapshot: isOfflineSnapshot)
                    }
                    ingredientsSection.id(SectionAnchor.ingredients)
                    instructionsSection.id(SectionAnchor.instructions)
                    RelatedRecipesStrip(
                        items: isOfflineSnapshot ? [] : viewModel.related,
                        onSelect: onSelectRelated
                    )
                    // US-13/14/15 integration: ratings + reviews hangs off
                    // the bottom of the scroll content. The section owns
                    // its own guest-identity sheet so the host doesn't
                    // need to coordinate presentation state.
                    RecipeDetailRatingsSection(viewModel: viewModel)
                }
                .padding(.bottom, DODSpacing.xl)
            }
        }
    }

    @ViewBuilder
    private var excerptText: some View {
        if !viewModel.listItem.excerpt.isEmpty {
            Text(viewModel.listItem.excerpt)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .padding(.horizontal, DODSpacing.md)
        }
    }

    /// AC-7.1 CTA. Hidden until the recipe detail has parsed instructions
    /// — without those, Cook Mode would open onto an empty step list.
    @ViewBuilder
    private var cookNowSection: some View {
        if let recipe = viewModel.recipe, !recipe.instructions.isEmpty {
            CookNowCTA(onTap: {
                Task { await viewModel.didTapCookMode() }
                isCookModePresented = true
            })
        }
    }

    private var metaPillItems: [RecipeDetailMetaPills.Item] {
        var result: [RecipeDetailMetaPills.Item] = []
        if let total = viewModel.recipe?.totalTime {
            result.append(.init(icon: "clock", label: format(duration: total)))
        }
        if let servings = viewModel.recipe?.servings {
            result.append(.init(icon: "person.2", label: "\(servings) servings"))
        }
        return result
    }

    private func quickJumpItems(proxy: ScrollViewProxy) -> [RecipeDetailQuickJump.Item] {
        [
            .init(title: "Ingredients") {
                withAnimation { proxy.scrollTo(SectionAnchor.ingredients, anchor: .top) }
            },
            .init(title: "Instructions") {
                withAnimation { proxy.scrollTo(SectionAnchor.instructions, anchor: .top) }
            },
        ]
    }

    // MARK: - Sections

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            Text("Ingredients")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
            if let ingredients = viewModel.recipe?.ingredients {
                ForEach(ingredients) { ingredient in
                    IngredientCheckRow(
                        ingredient: ingredient,
                        isChecked: viewModel.checkedIngredientIDs.contains(ingredient.id),
                        onToggle: { viewModel.toggleIngredient(ingredient.id) }
                    )
                }
            }
        }
        .padding(.horizontal, DODSpacing.md)
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            Text("Instructions")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
            if let instructions = viewModel.recipe?.instructions {
                ForEach(instructions) { step in
                    InstructionStepView(step: step)
                }
            }
        }
        .padding(.horizontal, DODSpacing.md)
    }

    // MARK: - Toolbars

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: DODSpacing.md) {
                // Save haptic is wired via `.sensoryFeedback(.success, trigger:
                // viewModel.isSaved)` on the body — no manual generator here.
                Button {
                    Task { await viewModel.toggleSaved() }
                } label: {
                    Image(systemName: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(viewModel.isSaved ? DODColor.accent : DODColor.label)
                }
                .accessibilityLabel(viewModel.isSaved ? "Unsave recipe" : "Save recipe")

                ShareLink(item: viewModel.canonicalURL) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(DODColor.label)
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        Task { await viewModel.didShare() }
                    }
                )
                .accessibilityLabel("Share recipe")
            }
        }
    }

    @ViewBuilder
    private var snackbar: some View {
        if let message = viewModel.snackbarMessage {
            Snackbar(message: message)
                .padding(.bottom, DODSpacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    viewModel.dismissSnackbar()
                }
        }
    }
}

// MARK: - Helpers

extension RecipeDetailView {

    fileprivate func handleLoadStateChange(_ newValue: RecipeDetailViewModel.LoadState) {
        if newValue == .unavailable {
            // Pop after a brief moment so the snackbar is visible.
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                dismiss()
            }
        }
        // US-10 / AC-10.1: if the deep link asked us to jump straight to
        // Cook Mode, do it the instant the recipe has instructions
        // populated. Same gating as the manual CTA (AC-7.1).
        guard newValue == .ready, pendingAutoCookMode else { return }
        guard let recipe = viewModel.recipe, !recipe.instructions.isEmpty else { return }
        pendingAutoCookMode = false
        Task { await viewModel.didTapCookMode() }
        isCookModePresented = true
    }

    fileprivate func format(duration: Duration) -> String {
        let seconds = Int(duration.components.seconds)
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours)h \(remainder)m"
    }
}
