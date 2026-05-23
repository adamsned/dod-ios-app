import AVKit
import DODDesignSystem
import DODDomain
import SwiftUI

/// Recipe detail screen. Header (AC-4.1) + ingredients (AC-4.2) + instructions
/// (AC-4.3) + optional video (AC-4.4, AC-4.5) + related (AC-4.6) +
/// save (AC-4.7) + share (AC-4.8). VoiceOver labels (AC-4.10).
/// Offline-aware (AC-4.9, AC-5.4, AC-5.5).
public struct RecipeDetailView: View {

    @State private var viewModel: RecipeDetailViewModel
    @State private var isOfflineSnapshot: Bool = false
    @Environment(\.dismiss) private var dismiss
    public let onSelectRelated: (RecipeListItem) -> Void

    public init(
        viewModel: RecipeDetailViewModel,
        onSelectRelated: @escaping (RecipeListItem) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
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
        .task {
            await viewModel.onAppear()
            isOfflineSnapshot = await viewModel.isOffline
        }
        .onChange(of: viewModel.loadState) { _, newValue in
            if newValue == .unavailable {
                // Pop after a brief moment so the snackbar is visible.
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loadingDetail:
            ScrollView {
                VStack(spacing: DODSpacing.md) {
                    LoadingSkeleton(cornerRadius: 0).frame(height: 280)
                    LoadingSkeleton().frame(height: 24).padding(.horizontal, DODSpacing.md)
                    LoadingSkeleton().frame(height: 16).padding(.horizontal, DODSpacing.lg)
                    LoadingSkeleton().frame(height: 16).padding(.horizontal, DODSpacing.lg)
                }
            }
            .accessibilityLabel("Loading recipe")
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

    private var readyBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DODSpacing.lg) {
                heroSection
                metaSection
                if let video = viewModel.recipe?.video {
                    videoSection(video)
                }
                ingredientsSection
                instructionsSection
                RelatedRecipesStrip(
                    items: isOfflineSnapshot ? [] : viewModel.related,
                    onSelect: onSelectRelated
                )
            }
            .padding(.bottom, DODSpacing.xl)
        }
    }

    private var heroSection: some View {
        let url = viewModel.recipe?.heroImageLargeURL ?? viewModel.listItem.heroImage
        return AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                LoadingSkeleton(cornerRadius: 0)
            }
        }
        .frame(height: 260)
        .clipped()
        .accessibilityLabel(viewModel.listItem.title)
    }

    private var metaSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text(viewModel.listItem.title)
                .dodFont(DODType.displayLarge)
                .foregroundStyle(DODColor.label)
            if !viewModel.listItem.excerpt.isEmpty {
                Text(viewModel.listItem.excerpt)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            metaRow
        }
        .padding(.horizontal, DODSpacing.md)
    }

    private var metaRow: some View {
        HStack(spacing: DODSpacing.md) {
            if let total = viewModel.recipe?.totalTime {
                metaItem(icon: "clock", label: format(duration: total))
            }
            if let servings = viewModel.recipe?.servings {
                metaItem(icon: "person.2", label: "\(servings) servings")
            }
        }
        .padding(.top, DODSpacing.xs)
    }

    private func metaItem(icon: String, label: String) -> some View {
        HStack(spacing: DODSpacing.xxs) {
            Image(systemName: icon).foregroundStyle(DODColor.labelSecondary)
            Text(label).dodFont(DODType.caption).foregroundStyle(DODColor.labelSecondary)
        }
    }

    @ViewBuilder
    private func videoSection(_ video: RecipeVideo) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("Video")
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
                .padding(.horizontal, DODSpacing.md)
            if isOfflineSnapshot {
                // AC-5.5 — saved-offline placeholder.
                RoundedRectangle(cornerRadius: DODSpacing.sm, style: .continuous)
                    .fill(DODColor.surfaceElevated)
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: DODSpacing.xs) {
                            Image(systemName: "play.slash")
                                .font(.title)
                                .foregroundStyle(DODColor.labelSecondary)
                            Text("Video unavailable offline")
                                .dodFont(DODType.caption)
                                .foregroundStyle(DODColor.labelSecondary)
                        }
                    )
                    .padding(.horizontal, DODSpacing.md)
            } else {
                VideoPlayer(player: AVPlayer(url: video.url))
                    .frame(height: 200)
                    .padding(.horizontal, DODSpacing.md)
            }
        }
    }

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

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: DODSpacing.md) {
                Button {
                    Task { await viewModel.toggleSaved() }
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                } label: {
                    Image(systemName: viewModel.isSaved ? "heart.fill" : "heart")
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

    private func format(duration: Duration) -> String {
        let seconds = Int(duration.components.seconds)
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours) hr" : "\(hours)h \(remainder)m"
    }
}
