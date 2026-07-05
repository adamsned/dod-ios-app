import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-596 — the auto-minimizing player panel for ``CookModeView``: the
/// transport controls plus a slim always-visible grabber that restores them in
/// one tap. Extracted here (and the `wakeControls` / `scheduleMinimize` timing
/// logic with it) so `CookModeView.swift` stays under the SwiftLint
/// `file_length` / `type_body_length` caps.
///
/// Behaviour: the controls start expanded and collapse after
/// `autoMinimizeSeconds` of no interaction so more step text shows. Any
/// interaction — a transport tap, the swipe, or a tap anywhere in the step area
/// or on the grabber — calls ``wakeControls()``, which re-expands instantly and
/// re-arms the idle timer. `0` seconds ("Never") disables auto-minimizing
/// entirely, and the panel never minimizes while the Done card is up.
extension CookModeView {

    /// The player transport plus its restore grabber. When minimized the
    /// transport collapses to zero height (yielding the room to the step
    /// ScrollView) and only the grabber remains, pinned where the controls were.
    @ViewBuilder
    var playerPanel: some View {
        VStack(spacing: 0) {
            restoreGrabber
            CookModePlayerControls(
                viewModel: viewModel,
                stepChangeAnimation: controlsAnimation,
                onFinish: { close() },
                onInteract: { wakeControls() }
            )
            .frame(height: controlsExpanded ? nil : 0)
            .opacity(controlsExpanded ? 1 : 0)
            .allowsHitTesting(controlsExpanded)
            .clipped()
        }
        .animation(controlsAnimation, value: controlsExpanded)
    }

    /// A slim, always-visible affordance pinned where the controls sit. When
    /// minimized it shows a `chevron.up` cue ("tap to bring the controls back");
    /// when expanded it's a quiet grabber pill. Tapping it always wakes.
    @ViewBuilder
    private var restoreGrabber: some View {
        Button {
            wakeControls()
        } label: {
            Group {
                if controlsExpanded {
                    Capsule()
                        .fill(DODColor.surfaceDivider)
                        .frame(width: 40, height: 5)
                } else {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DODColor.burntOrange)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .contentShape(Rectangle())
            .background(DODColor.surface)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cook-mode-controls-grabber")
        .accessibilityLabel(controlsExpanded ? "Hide controls" : "Show controls")
        .accessibilityHint("show the playback controls")
    }

    /// DUT-596 — the panel's expand/collapse animation, gated on Reduce Motion
    /// (constitution §7): `nil` (no motion) when the user asked to reduce motion,
    /// otherwise a smooth short ease.
    var controlsAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.25)
    }

    /// Re-expand the controls (animated) and re-arm the idle-minimize timer.
    /// Call from onAppear, every transport action, the swipe, a tap in the step
    /// area, and the grabber. Cheap + idempotent, so calling it often is fine.
    func wakeControls() {
        withAnimation(controlsAnimation) {
            controlsExpanded = true
        }
        scheduleMinimize()
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
}
