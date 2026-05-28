import DODDesignSystem
import DODDomain
import DODSupport
import Foundation
import SwiftUI

/// Hands-free cooking surface (US-7).
///
/// Presented as a `.fullScreenCover` from ``RecipeDetailView`` so the
/// transition reads as a deliberate "different mode" rather than a normal
/// detail push. Owns its own step navigation, ingredient checklist, and
/// the `UIApplication.isIdleTimerDisabled` toggle — see ``CookModeViewModel``
/// for the lifecycle contract.
///
/// Spec trace: AC-7.1 (CTA), AC-7.2 (layout), AC-7.3 (idle timer),
/// AC-7.4 (swipe + next/back + done), AC-7.5 (ingredients carry over),
/// AC-7.6 (Done exits), AC-7.7 (telemetry).
@MainActor
public struct CookModeView: View {

    @State private var viewModel: CookModeViewModel
    @State private var ingredientsDrawerVisible: Bool = false
    public let onClose: (Set<UUID>) -> Void
    /// Scale factor inherited from the host detail screen so the drawer
    /// ingredient rows agree with the scaled list the user just left. AC-7.5
    /// + US-31 carry-over.
    private let ingredientScaleFactor: Double

    public init(
        recipe: Recipe,
        initialCheckedIngredients: Set<UUID>,
        ingredientScaleFactor: Double = 1.0,
        onClose: @escaping (Set<UUID>) -> Void
    ) {
        _viewModel = State(
            initialValue: CookModeViewModel(
                recipe: recipe,
                initialCheckedIngredients: initialCheckedIngredients
            )
        )
        self.ingredientScaleFactor = ingredientScaleFactor
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: DODSpacing.lg) {
                    heroBlock
                    stepBody
                }
                .padding(.bottom, DODSpacing.xl)
            }
            ingredientsPullTab
            bottomControls
        }
        .background(DODColor.surface.ignoresSafeArea())
        .gesture(swipeGesture)
        .sheet(isPresented: $ingredientsDrawerVisible) {
            ingredientsDrawer
                .presentationDetents([.medium, .large])
        }
        .task {
            // Idempotent — see CookModeViewModel.beginCookMode().
            viewModel.beginCookMode()
        }
        .onDisappear {
            viewModel.endCookMode()
        }
    }

    // MARK: - Top bar (AC-7.2 step counter, AC-7.6 Done exit)

    private var topBar: some View {
        HStack(alignment: .center) {
            Button("Done") { close() }
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
                .accessibilityLabel("Exit Cook Mode")
            Spacer()
            Text(viewModel.recipe.title)
                .dodFont(DODType.heading)
                .foregroundStyle(DODColor.label)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            voiceModeToggle
            Text(stepCounterLabel)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .monospacedDigit()
                .accessibilityLabel(stepCounterAccessibilityLabel)
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.sm)
        .background(DODColor.surface)
    }

    private var stepCounterLabel: String {
        if viewModel.isFinished { return "Done" }
        return "Step \(viewModel.currentStepIndex + 1) of \(viewModel.stepCount)"
    }

    private var stepCounterAccessibilityLabel: String {
        if viewModel.isFinished { return "Cooking complete" }
        return "Step \(viewModel.currentStepIndex + 1) of \(viewModel.stepCount)"
    }

    // MARK: - Hero (AC-7.2)

    @ViewBuilder
    private var heroBlock: some View {
        if let url = viewModel.recipe.heroImageLargeURL ?? viewModel.recipe.heroImage {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        LoadingSkeleton(cornerRadius: 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 200)
                .allowsHitTesting(false)
            }
            .frame(height: 200)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Step body (AC-7.2 large step, AC-7.4 finished state)

    @ViewBuilder
    private var stepBody: some View {
        if viewModel.isFinished {
            doneCard
        } else if let step = viewModel.currentStep {
            stepCard(step)
        }
    }

    private func stepCard(_ step: RecipeInstruction) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            HStack(alignment: .top, spacing: DODSpacing.md) {
                Text("\(step.step)")
                    .dodFont(DODType.displayMedium)
                    .foregroundStyle(DODColor.cream)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(DODColor.burntOrange))
                    .accessibilityHidden(true)
                Text(step.text)
                    .dodFont(DODType.displayMedium)
                    .foregroundStyle(DODColor.label)
                    .lineSpacing(DODSpacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let duration = StepTimerParser.firstDuration(in: step.text) {
                CookTimer(duration: duration, stepText: step.text, liveActivitySink: viewModel)
            }
        }
        .padding(.horizontal, DODSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step.step). \(step.text)")
    }

    private var doneCard: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(DODColor.accent)
            Text("All done — enjoy!")
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
            Text("Tap Finish to leave Cook Mode.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DODSpacing.md)
    }

    // MARK: - Ingredients drawer (AC-7.2, AC-7.5)

    private var ingredientsPullTab: some View {
        Button {
            ingredientsDrawerVisible = true
        } label: {
            HStack(spacing: DODSpacing.xs) {
                Image(systemName: "chevron.up")
                Text("Ingredients")
                    .dodFont(DODType.bodyEmphasized)
                Text("(\(viewModel.checkedIngredientIDs.count) of \(viewModel.recipe.ingredients.count))")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
            }
            .foregroundStyle(DODColor.label)
            .padding(.vertical, DODSpacing.sm)
            .frame(maxWidth: .infinity)
            .background(DODColor.surfaceElevated)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show ingredients")
    }

    private var ingredientsDrawer: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DODSpacing.sm) {
                    ForEach(viewModel.recipe.ingredients) { ingredient in
                        ingredientRow(for: ingredient)
                    }
                }
                .padding(.horizontal, DODSpacing.md)
                .padding(.vertical, DODSpacing.md)
            }
            .navigationTitle("Ingredients")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    // MARK: - Bottom controls (AC-7.4)

    @ViewBuilder
    private var bottomControls: some View {
        HStack(spacing: DODSpacing.sm) {
            if viewModel.currentStepIndex > 0 || viewModel.isFinished {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { viewModel.goBack() }
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(DODColor.label)
                .accessibilityLabel("Previous step")
            }
            Button {
                advance()
            } label: {
                Label(primaryButtonLabel, systemImage: primaryButtonSymbol)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(DODColor.accent)
            .accessibilityLabel(primaryButtonLabel)
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.sm)
        .background(DODColor.surface)
    }

    private var primaryButtonLabel: String {
        if viewModel.isFinished { return "Finish" }
        return viewModel.isOnLastStep ? "Done cooking" : "Next"
    }

    private var primaryButtonSymbol: String {
        if viewModel.isFinished { return "checkmark" }
        return viewModel.isOnLastStep ? "checkmark.circle.fill" : "chevron.right"
    }

    // MARK: - Gestures (AC-7.4)

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .local)
            .onEnded { value in
                let horizontalThreshold: CGFloat = 50
                let isMostlyHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.2
                guard isMostlyHorizontal else { return }
                if value.translation.width < -horizontalThreshold {
                    withAnimation(.easeInOut(duration: 0.2)) { advance() }
                } else if value.translation.width > horizontalThreshold {
                    withAnimation(.easeInOut(duration: 0.2)) { viewModel.goBack() }
                }
            }
    }

    // MARK: - Helpers

    private func advance() {
        if viewModel.isFinished {
            close()
        } else {
            viewModel.goNext()
        }
    }

    private func close() {
        viewModel.endCookMode()
        onClose(viewModel.checkedIngredientIDs)
    }
}

// MARK: - Voice Mode toggle (US-40 / AC-40.1)

extension CookModeView {
    /// Voice Mode toggle (US-40 / AC-40.1) — a `speaker.wave.2` button that
    /// fills (`speaker.wave.2.fill`) when reading is on. Tapping flips
    /// ``CookModeViewModel/isVoiceModeEnabled``; turning it on immediately
    /// reads the current step (AC-40.2), turning it off stops the reader.
    /// Pulled into an extension so the type body stays under the SwiftLint
    /// length cap (mirrors `ingredientRow` below).
    @ViewBuilder
    fileprivate var voiceModeToggle: some View {
        Button {
            viewModel.toggleVoiceMode()
        } label: {
            Image(systemName: viewModel.isVoiceModeEnabled ? "speaker.wave.2.fill" : "speaker.wave.2")
                .foregroundStyle(viewModel.isVoiceModeEnabled ? DODColor.accent : DODColor.label)
        }
        .accessibilityIdentifier("cook-mode-voice-toggle")
        .accessibilityLabel("Voice Mode")
        .accessibilityHint(viewModel.isVoiceModeEnabled ? "stop reading steps aloud" : "read steps aloud")
        .accessibilityAddTraits(viewModel.isVoiceModeEnabled ? .isSelected : [])
    }
}

// MARK: - Ingredients drawer row

extension CookModeView {
    /// One row in the ingredients drawer with the scaled `displayText`
    /// (US-31 / AC-31.4 carry-over into Cook Mode). Pulled into an
    /// extension so the type body stays under the SwiftLint length cap.
    @ViewBuilder
    fileprivate func ingredientRow(for ingredient: RecipeIngredient) -> some View {
        IngredientCheckRow(
            ingredient: ingredient,
            displayText: FractionRenderer.scale(ingredient.text, by: ingredientScaleFactor),
            isChecked: viewModel.checkedIngredientIDs.contains(ingredient.id),
            onToggle: { viewModel.toggleIngredient(ingredient.id) }
        )
    }
}
