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
    /// DUT-599 — `internal` so `CookModeView+Controls.swift` can open the drawer
    /// from the carrot button wired into the transport's secondary row.
    @State var ingredientsDrawerVisible: Bool = false
    /// DUT-529 — belt-and-suspenders idle-timer safety net. `.onDisappear`
    /// already restores the idle timer on a normal teardown; this observer also
    /// restores it when the app backgrounds (so an atypical teardown that never
    /// fires `.onDisappear` can't leave `isIdleTimerDisabled` stuck on), and
    /// re-arms it on return to `.active` if the session is still up. Both
    /// `begin`/`endCookMode` are idempotent, so this never double-restores.
    @Environment(\.scenePhase) private var scenePhase
    /// DUT-529 — when Reduce Motion is on, drop the step-change slide/scale
    /// animation (constitution §7); the step swap still happens, just without the
    /// motion. Mirrors the `LoadingSkeleton` shimmer guard.
    /// `internal` (not `private`) so `CookModeView+Controls.swift` can gate the
    /// panel's collapse/expand animation on Reduce Motion (constitution §7).
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    // `internal` (not `private`) so the step-body composition in
    // `CookModeView+StepBody.swift` can present the journal-log sheet.
    /// DUT-326 — drives the "Add to Cooking Journal" capture sheet on the
    /// Done card.
    @State var isJournalLogPresented: Bool = false
    /// T-912 / DUT-551 (CL-306) — drives the Heat Coach sheet presented OVER
    /// Cook Mode's full-screen cover from a heat-related step's shortcut. Cook
    /// Mode is a `.fullScreenCover`, so a tab switch would be invisible under it;
    /// a `.sheet` layers on top instead. `internal` so `CookModeView+StepBody`
    /// can flip it. Only shown when `heatCoachSheet != nil`.
    @State var isHeatCoachPresented: Bool = false
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
    /// T-912 / DUT-551 (CL-306) — builds the Heat Coach surface for the
    /// heat-step shortcut. Presented as a `.sheet` OVER this full-screen cover
    /// (see `isHeatCoachPresented`). The `HeatCoachView` lives in
    /// `DODFeatureFeed`, which this package must not import, so the host injects
    /// a type-erased `AnyView` builder. `nil` (the default) hides the shortcut on
    /// every step — previews and hosts that don't wire hub routing stay
    /// unaffected (same seam as `onLogCook`). `internal` (not `private`) so
    /// `CookModeView+StepBody.swift` can gate the shortcut on it.
    let heatCoachSheet: (() -> AnyView)?
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

    /// DUT-517 — the same "Use Metric Units" preference Recipe Detail reads, so
    /// the Cook Mode ingredient drawer shows the metric measurements the user
    /// saw a tap earlier rather than reverting to the author's imperial units on
    /// the one screen they cook from. Applied to the already-scaled line;
    /// non-convertible lines pass through unchanged. Display-time transform only.
    @AppStorage(IngredientMetricConverter.preferenceKey)
    var useMetricUnits: Bool = false

    /// DUT-596 — the idle delay (seconds) after which the player controls
    /// auto-minimize so more step text shows. `0` == Never. Shared with the
    /// Settings picker via ``CookModeControlsAutoMinimize/preferenceKey``.
    /// `internal` (not `private`) so the auto-minimize logic in
    /// `CookModeView+Controls.swift` can read the delay.
    @AppStorage(CookModeControlsAutoMinimize.preferenceKey)
    var autoMinimizeSeconds: Int = CookModeControlsAutoMinimize.defaultSeconds

    /// DUT-596 — whether the player control panel is currently expanded. Flips to
    /// `false` after `autoMinimizeSeconds` of no interaction (never while
    /// finished); ANY interaction restores it via ``wakeControls()``. `internal`
    /// so `CookModeView+Controls.swift` drives it.
    @State var controlsExpanded = true

    /// DUT-596 — the in-flight "minimize after the idle delay" task, cancelled +
    /// rescheduled on every interaction and torn down on disappear. `internal` so
    /// `CookModeView+Controls.swift` owns its lifecycle.
    @State var minimizeTask: Task<Void, Never>?

    public init(
        recipe: Recipe,
        initialCheckedIngredients: Set<UUID>,
        ingredientScaleFactor: Double = 1.0,
        onClose: @escaping (Set<UUID>) -> Void,
        onLogCook: ((CookLogEntry) -> Void)? = nil,
        heatCoachSheet: (() -> AnyView)? = nil
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
        self.heatCoachSheet = heatCoachSheet
    }

    public var body: some View {
        VStack(spacing: 0) {
            cookModeHeader
            ScrollView {
                VStack(alignment: .leading, spacing: DODSpacing.lg) {
                    heroBlock
                    stepBody
                }
                .padding(.top, DODSpacing.sm)
                .padding(.bottom, DODSpacing.md)
            }
            // DUT-596/599 — tapping the step area while the controls are
            // collapsed brings them back (one easy tap). While expanded a tap is
            // a no-op so it never fights reading. `contentShape` so the tap lands
            // on the whole scroll region; a tap-only gesture that leaves
            // scrolling alone.
            .contentShape(Rectangle())
            .onTapGesture { if !controlsExpanded { wakeControls() } }
            // DUT-599 — scrolling DOWN the step hides the controls (more room to
            // read); scrolling back UP pops them right back. `onScrollGeometryChange`
            // is iOS 18+/macOS 15+, so the modifier guards both `#if os(iOS)` and
            // `if #available(iOS 18)` (the package deploys below both) and no-ops
            // gracefully on older OSes — the idle timer + grabber still work.
            .modifier(
                StepScrollHideModifier { oldOffset, newOffset in
                    handleStepScroll(from: oldOffset, to: newOffset)
                }
            )
            // DUT-596 (was DUT-582 / CL-315) — the auto-minimizing player panel:
            // the transport collapses (after an idle delay, a scroll-down, or a
            // tap on the grabber) so more step text shows; the grabber toggles it
            // back and mini prev/next arrows keep navigation available while
            // collapsed.
            playerPanel
            CookModeStepIndicator(viewModel: viewModel)
                .padding(.bottom, DODSpacing.xs)
        }
        .background(DODColor.surface.ignoresSafeArea())
        .gesture(swipeGesture)
        .sheet(isPresented: $ingredientsDrawerVisible) {
            ingredientsDrawer
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isJournalLogPresented) {
            // DUT-326 — self-contained capture sheet (equivalent to the Feed
            // package's CookJournalEntryView, which this package can't import).
            CookModeJournalLogSheet(recipe: viewModel.recipe) { entry in
                onLogCook?(entry)
            }
        }
        // T-912 / DUT-551 — Heat Coach, presented as a sheet OVER this
        // full-screen cover from a heat-related step's shortcut (a tab switch
        // would be invisible under the cover). The host-injected builder returns
        // an `AnyView` (the `HeatCoachView` type lives in `DODFeatureFeed`).
        .sheet(isPresented: $isHeatCoachPresented) {
            if let heatCoachSheet {
                heatCoachSheet()
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
            // DUT-596 — start visible, then arm the idle-minimize timer.
            wakeControls()
        }
        .onReceive(timerTicker) { _ in viewModel.tickTimers() }
        .sensoryFeedback(.success, trigger: viewModel.timerCompletionTick)
        // DUT-693 (PR3) — buzz when the cook completes (Done card flip).
        .sensoryFeedback(.success, trigger: viewModel.isFinished)
        // DUT-693 (PR3) — light selection tick on every step change; keyed on
        // the current-step index so it covers the Next/Back buttons, the swipe
        // gesture, and the mini-nav arrows with one modifier.
        .sensoryFeedback(.selection, trigger: viewModel.currentStepIndex)
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
        .onChange(of: viewModel.isFinished) { _, _ in
            announceCurrentStep()
            // DUT-596 — the Done card must stay fully visible: expand and keep
            // the controls up (scheduleMinimize no-ops while finished).
            wakeControls()
        }
        .onDisappear {
            // DUT-596 — cancel the in-flight minimize task so it can't fire into
            // a torn-down view.
            minimizeTask?.cancel()
            minimizeTask = nil
            viewModel.endCookMode()
        }
        // DUT-529 — idle-timer safety net for atypical teardowns that never fire
        // `.onDisappear`. On background, restore *just* the idle timer (leaving
        // the Live Activity + timers running, US-11); on return to active, re-arm
        // it if the session is still live. Both calls are idempotent and preserve
        // the `didBegin` / `priorIdleTimerDisabled` symmetry, so they never
        // double-restore against the `.onDisappear` `endCookMode` above.
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                viewModel.suspendIdleTimerForBackground()
            case .active:
                viewModel.resumeIdleTimerIfActive()
            default:
                break
            }
        }
    }

    /// DUT-529 — the step-change animation, gated on Reduce Motion: `nil` (no
    /// animation) when the user has asked to reduce motion, otherwise the usual
    /// short ease. Used by the Next/Previous buttons and the swipe gesture.
    private var stepChangeAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    // MARK: - Header (AC-7.2 step counter, AC-7.6 Done exit, DUT-325 layout)
    //
    // `cookModeHeader` (the slim Done + voice-controls top row plus the recipe
    // name with the step counter directly beneath it) and the voice-controls
    // cluster live in `CookModeView+Header.swift` so this file stays under the
    // SwiftLint `file_length` cap.

    // MARK: - Hero (AC-7.2)

    /// DUT-582 (CL-315) — the "album art": the recipe hero, taller (~340pt) and
    /// rounded (`DODRadius.standard`), shown on every step. No bottom gradient
    /// now that the step text lives below the image rather than over it.
    private let heroHeight: CGFloat = 340

    @ViewBuilder
    private var heroBlock: some View {
        if let url = viewModel.recipe.heroImageLargeURL ?? viewModel.recipe.heroImage {
            // T-839 — reliable cached loader (ReliableImage), not AsyncImage,
            // so the Cook Mode hero doesn't stick on the skeleton.
            ReliableImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    // DUT-524 — neutral static placeholder instead of the
                    // infinite skeleton shimmer when the hero can't load.
                    DODColor.surfaceElevated
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 40))
                                .foregroundStyle(DODColor.labelSecondary)
                        )
                case .empty:
                    LoadingSkeleton(cornerRadius: DODRadius.standard)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: heroHeight)
            .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
            .padding(.horizontal, DODSpacing.md)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Ingredients drawer (AC-7.2, AC-7.5)
    //
    // DUT-599 — the old bottom "Ingredients" pull tab is gone; ingredients now
    // open from the `carrot.fill` button in the transport's secondary row (see
    // `CookModePlayerControls`), wired via `openIngredients()` in
    // `CookModeView+Controls.swift`. The drawer itself is unchanged.

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
            // Nav-consistency sweep: the drawer is a sheet, so it gets the app's
            // standard trailing "Done" dismissal (plus a drag indicator on the
            // sheet itself) instead of being a swipe-only dead end.
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        ingredientsDrawerVisible = false
                    }
                    .tint(DODColor.burntOrange)
                    .accessibilityIdentifier("cook-mode-ingredients-done")
                }
            }
        }
    }

    // MARK: - Gestures (AC-7.4)

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .local)
            .onEnded { value in
                let horizontalThreshold: CGFloat = 50
                let isMostlyHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.2
                guard isMostlyHorizontal else { return }
                if value.translation.width < -horizontalThreshold {
                    wakeControls()  // DUT-596
                    withAnimation(stepChangeAnimation) { advance() }
                } else if value.translation.width > horizontalThreshold {
                    wakeControls()  // DUT-596
                    withAnimation(stepChangeAnimation) { viewModel.goBack() }
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
        let scaled = FractionRenderer.scale(ingredient.text, by: ingredientScaleFactor)
        IngredientCheckRow(
            ingredient: ingredient,
            displayText: useMetricUnits ? IngredientMetricConverter.metric(scaled) : scaled,
            isChecked: viewModel.checkedIngredientIDs.contains(ingredient.id),
            onToggle: { viewModel.toggleIngredient(ingredient.id) }
        )
    }
}
