import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-596/599 — the auto-minimizing player panel for ``CookModeView``: the
/// transport controls plus a slim always-visible grabber, and (when collapsed)
/// a mini prev/next nav bar. Extracted here (with the `wakeControls` /
/// `collapseControls` / `scheduleMinimize` / scroll logic) so
/// `CookModeView.swift` stays under the SwiftLint `file_length` /
/// `type_body_length` caps.
///
/// Behaviour: the controls start expanded and collapse after
/// `autoMinimizeSeconds` of no interaction, on a scroll DOWN of the step, or on
/// a tap of the grabber, so more step text shows. They come back on a scroll UP,
/// a tap of the grabber, or a tap in the collapsed step area. While collapsed,
/// mini prev/next arrows keep step navigation available. `0` seconds ("Never")
/// disables the idle auto-minimize; the panel never minimizes while the Done
/// card is up.
extension CookModeView {

    /// The player transport plus its restore grabber. When collapsed the full
    /// transport is replaced by the compact ``miniNav`` (shorter, so the step
    /// ScrollView gets the room), with the grabber pinned above it.
    @ViewBuilder
    var playerPanel: some View {
        VStack(spacing: 0) {
            grabber
            if controlsExpanded {
                CookModePlayerControls(
                    viewModel: viewModel,
                    stepChangeAnimation: controlsAnimation,
                    onFinish: { close() },
                    onInteract: { wakeControls() },
                    onIngredients: { openIngredients() }
                )
                .transition(.opacity)
            } else {
                miniNav
                    .transition(.opacity)
            }
        }
        .animation(controlsAnimation, value: controlsExpanded)
    }

    /// A slim, always-visible affordance pinned where the controls sit that
    /// TOGGLES the panel: a `chevron.down` cue when expanded (tap to collapse —
    /// DUT-599 makes collapsing one easy tap) and a `chevron.up` when collapsed
    /// (tap to bring the controls back).
    @ViewBuilder
    private var grabber: some View {
        Button {
            toggleControls()
        } label: {
            Image(systemName: controlsExpanded ? "chevron.down" : "chevron.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DODColor.burntOrange)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .contentShape(Rectangle())
                .background(DODColor.surface)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cook-mode-controls-grabber")
        .accessibilityLabel(controlsExpanded ? "Hide controls" : "Show controls")
        .accessibilityHint(controlsExpanded ? "collapse the playback controls" : "show the playback controls")
    }

    // MARK: - Mini nav (collapsed)

    /// DUT-599 — compact prev/next arrows shown in place of the transport while
    /// the controls are collapsed (where the ingredients pull tab used to sit),
    /// so a cook can still move between steps without expanding. Navigating keeps
    /// the panel collapsed. Hidden on the Done card (which never collapses).
    @ViewBuilder
    private var miniNav: some View {
        HStack(spacing: DODSpacing.xl) {
            Spacer(minLength: 0)
            if showsMiniPrevious {
                miniNavButton(symbol: "arrow.backward", label: "Previous Step") {
                    withAnimation(controlsAnimation) { viewModel.goBack() }
                }
                .accessibilityIdentifier("cook-mode-mini-previous")
            } else {
                Color.clear.frame(width: miniNavDiameter, height: miniNavDiameter)
            }
            miniNavButton(symbol: "arrow.forward", label: "Next Step") {
                withAnimation(controlsAnimation) { viewModel.goNext() }
            }
            .accessibilityIdentifier("cook-mode-mini-next")
            Spacer(minLength: 0)
        }
        .padding(.vertical, DODSpacing.xs)
        .frame(maxWidth: .infinity)
        .background(DODColor.surface)
    }

    private var showsMiniPrevious: Bool {
        viewModel.currentStepIndex > 0
    }

    // DUT-616: 44pt minimum hit target (HIG). The glyph stays at 18pt; only the
    // frame/hit area grows, matching the >=44pt siblings.
    private var miniNavDiameter: CGFloat { 44 }

    private func miniNavButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DODColor.cream)
                .frame(width: miniNavDiameter, height: miniNavDiameter)
                .background(Circle().fill(DODColor.accent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Expand / collapse

    /// DUT-596 — the panel's expand/collapse animation, gated on Reduce Motion
    /// (constitution §7): `nil` (no motion) when the user asked to reduce motion,
    /// otherwise a smooth short ease.
    var controlsAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.25)
    }

    /// DUT-599 — the grabber toggle: collapse when expanded, expand when not.
    func toggleControls() {
        if controlsExpanded {
            collapseControls()
        } else {
            wakeControls()
        }
    }

    /// Re-expand the controls (animated) and re-arm the idle-minimize timer.
    /// Call from onAppear, every transport action, the swipe, a tap in the
    /// collapsed step area, a scroll UP, and the grabber. Cheap + idempotent.
    func wakeControls() {
        withAnimation(controlsAnimation) {
            controlsExpanded = true
        }
        scheduleMinimize()
    }

    /// DUT-599 — collapse the controls now (grabber tap / scroll down). Cancels
    /// the idle timer so it can't immediately re-collapse an already-collapsed
    /// panel. Never collapses on the Done card.
    func collapseControls() {
        guard !viewModel.isFinished else { return }
        minimizeTask?.cancel()
        minimizeTask = nil
        withAnimation(controlsAnimation) {
            controlsExpanded = false
        }
    }

    /// (Re)arm the delayed minimize. Cancels any in-flight task first. No-op when
    /// the delay is `Never` (0) or the Done card is up (it must stay visible).
    /// Otherwise sleeps `autoMinimizeSeconds` and, if not cancelled, collapses
    /// the controls (animated).
    func scheduleMinimize() {
        minimizeTask?.cancel()
        guard CookModeControlsAutoMinimize.shouldAutoMinimize(afterSeconds: autoMinimizeSeconds),
            !viewModel.isFinished
        else {
            minimizeTask = nil
            return
        }
        let delay = autoMinimizeSeconds
        minimizeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, !viewModel.isFinished else { return }
            withAnimation(controlsAnimation) {
                controlsExpanded = false
            }
        }
    }

    // MARK: - Scroll-driven hide (DUT-599)

    /// Collapse the controls on a scroll DOWN the step (more room to read) and
    /// bring them back on a scroll UP. A small threshold ignores sub-pixel jitter
    /// and the tiny offset settle a collapse/expand itself produces, so the two
    /// don't fight. No-op on the Done card.
    func handleStepScroll(from oldOffset: CGFloat, to newOffset: CGFloat) {
        switch CookModeScrollHide.action(
            deltaY: newOffset - oldOffset,
            controlsExpanded: controlsExpanded,
            isFinished: viewModel.isFinished
        ) {
        case .collapse: collapseControls()
        case .expand: wakeControls()
        case nil: break
        }
    }

    // MARK: - Ingredients

    /// DUT-599 — open the ingredients drawer from the carrot button, and treat it
    /// as an interaction so the idle timer re-arms.
    func openIngredients() {
        wakeControls()
        ingredientsDrawerVisible = true
    }
}

/// DUT-599 — applies the scroll-position observer that drives the hide-on-scroll
/// behaviour, guarded so it compiles + runs only where the API exists
/// (`onScrollGeometryChange` is iOS 18+/macOS 15+; the package deploys below
/// both). On older OSes it no-ops and the idle timer + grabber still work.
struct StepScrollHideModifier: ViewModifier {

    let onScroll: (CGFloat, CGFloat) -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { oldOffset, newOffset in
                onScroll(oldOffset, newOffset)
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// DUT-599 — the pure scroll → control-visibility rule, extracted so the
/// collapse-on-scroll-down / expand-on-scroll-up behaviour is L1-testable
/// without booting a SwiftUI host (like ``CookModeProgress`` and
/// ``CookModeControlsAutoMinimize/shouldAutoMinimize(afterSeconds:)``).
enum CookModeScrollHide {

    enum Action: Equatable { case collapse, expand }

    /// - `deltaY`: new contentOffset.y minus the previous one (positive = the
    ///   content moved up, i.e. the user scrolled DOWN toward later text).
    /// - `threshold`: filters sub-pixel jitter and the tiny offset settle that a
    ///   collapse/expand itself produces, so the two never fight.
    ///
    /// Returns `.collapse` on a scroll DOWN while expanded, `.expand` on a scroll
    /// UP while collapsed, and `nil` otherwise (below threshold, on the Done
    /// card, or already in the target state).
    static func action(
        deltaY: CGFloat,
        controlsExpanded: Bool,
        isFinished: Bool,
        threshold: CGFloat = 6
    ) -> Action? {
        guard !isFinished, abs(deltaY) > threshold else { return nil }
        if deltaY > 0 {
            return controlsExpanded ? .collapse : nil
        }
        return controlsExpanded ? nil : .expand
    }
}
