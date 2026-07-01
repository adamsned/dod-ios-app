import Combine
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

    // `internal` (not `private`) so the header composition in
    // `CookModeView+Header.swift` can read the view model.
    @State var viewModel: CookModeViewModel
    @State private var ingredientsDrawerVisible: Bool = false
    // `internal` (not `private`) so the step-body composition in
    // `CookModeView+StepBody.swift` can present the journal-log sheet.
    /// DUT-326 — drives the "Add to Cooking Journal" capture sheet on the
    /// Done card.
    @State var isJournalLogPresented: Bool = false
    /// DUT-293/294 — ticks the VM's step timers ~1×/s while Cook Mode is on
    /// screen, regardless of which step is shown, so a running timer on a step
    /// you've navigated away from still counts down + completes.
    private let timerTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    public let onClose: (Set<UUID>) -> Void
    /// DUT-326 — optional sink for "log this cook" from the Done card. When
    /// non-nil, the Done card shows an "Add to Cooking Journal" CTA; on Save
    /// the assembled ``CookLogEntry`` (photo persisted, caption attached) is
    /// handed here for the host to write to the journal store. `nil` (the
    /// default) hides the CTA entirely — previews and hosts that don't wire
    /// persistence stay unaffected.
    public let onLogCook: ((CookLogEntry) -> Void)?
    /// Scale factor inherited from the host detail screen so the drawer
    /// ingredient rows agree with the scaled list the user just left. AC-7.5
    /// + US-31 carry-over.
    private let ingredientScaleFactor: Double

    // `internal` (not `private`) so `CookModeView+StepBody.swift` can resolve
    // the temperature unit for the displayed step text (DUT-245).
    /// DUT-245 — the same temperature-unit preference Recipe Detail reads, so
    /// Cook Mode shows the converted temps the user saw a tap earlier (rather
    /// than reverting to the author's raw Fahrenheit on the one screen they
    /// cook from). `nil` ("Recipe default" / absent / malformed) leaves the
    /// step text exactly as written. Display-time transform only.
    @AppStorage(TemperatureConverter.preferenceKey)
    var temperatureUnitRaw: String = ""

    public init(
        recipe: Recipe,
        initialCheckedIngredients: Set<UUID>,
        ingredientScaleFactor: Double = 1.0,
        onClose: @escaping (Set<UUID>) -> Void,
        onLogCook: ((CookLogEntry) -> Void)? = nil
    ) {
        _viewModel = State(
            initialValue: CookModeViewModel(
                recipe: recipe,
                initialCheckedIngredients: initialCheckedIngredients
            )
        )
        self.ingredientScaleFactor = ingredientScaleFactor
        self.onClose = onClose
        self.onLogCook = onLogCook
    }

    public var body: some View {
        VStack(spacing: 0) {
            cookModeHeader
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
        .sheet(isPresented: $isJournalLogPresented) {
            // DUT-326 — self-contained capture sheet (equivalent to the Feed
            // package's CookJournalEntryView, which this package can't import).
            CookModeJournalLogSheet(recipe: viewModel.recipe) { entry in
                onLogCook?(entry)
            }
        }
        // DUT-328 — one-time "this may sound robotic, get a better voice" prompt
        // when Voice Mode turns on with only a robotic voice installed. Owns its
        // own state (in `CookModeView+VoicePrompt.swift`) so this body stays one
        // line and under the SwiftLint type_body_length cap.
        .cookModeVoiceUpgradePrompt(viewModel: viewModel)
        .task {
            // Idempotent — see CookModeViewModel.beginCookMode().
            viewModel.beginCookMode()
        }
        .onReceive(timerTicker) { _ in viewModel.tickTimers() }
        .sensoryFeedback(.success, trigger: viewModel.timerCompletionTick)
        // DUT-401 — a step timer reaching 00:00 had only visual + haptic
        // feedback; announce it so a cook who set the phone down (or a
        // VoiceOver user) hears it. Paired with the same completion trigger the
        // haptic uses. Skip the initial 0 so mounting doesn't announce.
        .onChange(of: viewModel.timerCompletionTick) { _, tick in
            if tick > 0 { announce("Timer complete.") }
        }
        // DUT-401 — advancing/going back swaps the step silently; announce the
        // new step (or the completion state) so VoiceOver users aren't left
        // hunting for the changed text after tapping Next.
        .onChange(of: viewModel.currentStepIndex) { _, _ in announceCurrentStep() }
        .onChange(of: viewModel.isFinished) { _, _ in announceCurrentStep() }
        .onDisappear {
            viewModel.endCookMode()
        }
    }

    // MARK: - Header (AC-7.2 step counter, AC-7.6 Done exit, DUT-325 layout)
    //
    // `cookModeHeader` (the slim Done + voice-controls top row plus the recipe
    // name with the step counter directly beneath it) and the voice-controls
    // cluster live in `CookModeView+Header.swift` so this file stays under the
    // SwiftLint `file_length` cap.

    // MARK: - Hero (AC-7.2)

    @ViewBuilder
    private var heroBlock: some View {
        if let url = viewModel.recipe.heroImageLargeURL ?? viewModel.recipe.heroImage {
            ZStack(alignment: .bottomLeading) {
                // T-839 — reliable cached loader (ReliableImage), not AsyncImage,
                // so the Cook Mode hero doesn't stick on the skeleton.
                ReliableImage(url: url) { phase in
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
                .dodBorderedButton()
                .tint(DODColor.label)
                .accessibilityLabel("Previous step")
            }
            Button {
                advance()
            } label: {
                Label(primaryButtonLabel, systemImage: primaryButtonSymbol)
                    .frame(maxWidth: .infinity)
            }
            .dodProminentButton()
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

    /// `internal` (not `private`) so the header's Done button in
    /// `CookModeView+Header.swift` can call it.
    func close() {
        viewModel.endCookMode()
        onClose(viewModel.checkedIngredientIDs)
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
