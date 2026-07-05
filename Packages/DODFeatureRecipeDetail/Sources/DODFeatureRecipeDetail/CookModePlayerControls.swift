import DODDesignSystem
import SwiftUI

/// DUT-582 (CL-315) — Cook Mode's music/podcast-style transport bar.
///
/// A single row of circular brand-colored controls, laid out like a media
/// player: **Previous** and **Next** flank a large center **Voice play/pause**
/// button, with a secondary row underneath carrying **Replay** and a **speed**
/// control (the pacing menu, surfaced as a visible affordance).
///
/// This is a pure presentation layer over ``CookModeViewModel`` — it wires the
/// existing bindings (`goBack`/`goNext`, `toggleVoiceMode`/`replayCurrentStep`,
/// `speedUp`/`slowDown`) and holds no state of its own. All controls render on
/// brand tokens (`burntOrange`/`accent`/`cream`); nothing renders grey.
///
/// Center semantics: the big button is a **Voice play/pause**. When Voice Mode
/// is OFF it shows a play glyph; tapping turns Voice Mode on AND speaks the
/// current step immediately (`replayCurrentStep`) so "play" reads aloud right
/// away. When ON it shows a pause glyph and tapping stops the reader. In the
/// finished state it becomes a "Finish" affordance that closes Cook Mode.
struct CookModePlayerControls: View {

    let viewModel: CookModeViewModel
    /// The step-change animation (nil under Reduce Motion), passed down from the
    /// host so Prev/Next animate consistently with the swipe gesture.
    let stepChangeAnimation: Animation?
    /// Invoked when the center button acts as "Finish" in the done state.
    let onFinish: () -> Void

    private var showsPrevious: Bool {
        viewModel.currentStepIndex > 0 || viewModel.isFinished
    }

    var body: some View {
        VStack(spacing: DODSpacing.sm) {
            transportRow
            secondaryRow
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(DODColor.surface)
    }

    // MARK: - Transport row (Prev / Voice play-pause / Next)

    private var transportRow: some View {
        HStack(spacing: DODSpacing.lg) {
            Spacer(minLength: 0)
            previousButton
            centerButton
            nextButton
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var previousButton: some View {
        if showsPrevious {
            flankButton(symbol: "backward.end.fill", label: "Previous Step") {
                withAnimation(stepChangeAnimation) { viewModel.goBack() }
            }
            .accessibilityIdentifier("cook-mode-previous")
        } else {
            // Reserve the slot so the center button stays centered on step 1.
            Color.clear.frame(width: flankDiameter, height: flankDiameter)
        }
    }

    private var nextButton: some View {
        flankButton(symbol: "forward.end.fill", label: "Next Step") {
            withAnimation(stepChangeAnimation) { viewModel.goNext() }
        }
        .accessibilityIdentifier("cook-mode-next")
        // Advancing past the last step is handled by the view model (isFinished);
        // hide Next only once fully finished so the row collapses to Finish.
        .opacity(viewModel.isFinished ? 0 : 1)
        .disabled(viewModel.isFinished)
    }

    /// The large center control: Voice play/pause (podcast-style), or Finish in
    /// the done state.
    private var centerButton: some View {
        Button(action: centerAction) {
            Image(systemName: centerSymbol)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(DODColor.cream)
                .frame(width: centerDiameter, height: centerDiameter)
                .background(Circle().fill(DODColor.burntOrange))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cook-mode-voice-playpause")
        .accessibilityLabel(centerAccessibilityLabel)
        .accessibilityHint(centerAccessibilityHint)
        .accessibilityAddTraits(viewModel.isVoiceModeEnabled ? .isSelected : [])
    }

    private func centerAction() {
        if viewModel.isFinished {
            onFinish()
            return
        }
        let wasOff = !viewModel.isVoiceModeEnabled
        viewModel.toggleVoiceMode()
        // Turning voice ON should speak the current step immediately so the
        // "play" button behaves like a player. `toggleVoiceMode` already reads
        // on turn-on, but replay guarantees it even if that path changes.
        if wasOff, viewModel.isVoiceModeEnabled {
            viewModel.replayCurrentStep()
        }
    }

    private var centerSymbol: String {
        if viewModel.isFinished { return "checkmark" }
        return viewModel.isVoiceModeEnabled ? "pause.fill" : "play.fill"
    }

    private var centerAccessibilityLabel: String {
        if viewModel.isFinished { return "Finish" }
        return viewModel.isVoiceModeEnabled ? "Pause voice" : "Play voice"
    }

    private var centerAccessibilityHint: String {
        if viewModel.isFinished { return "leave Cook Mode" }
        return viewModel.isVoiceModeEnabled ? "stop reading steps aloud" : "read this step aloud"
    }

    // MARK: - Secondary row (Replay + speed)

    private var secondaryRow: some View {
        HStack(spacing: DODSpacing.xl) {
            Spacer(minLength: 0)
            replayButton
            speedButton
            Spacer(minLength: 0)
        }
        .opacity(viewModel.isFinished ? 0 : 1)
        .disabled(viewModel.isFinished)
        .accessibilityHidden(viewModel.isFinished)
    }

    private var replayButton: some View {
        secondaryButton(symbol: "arrow.trianglehead.counterclockwise", title: "Replay") {
            viewModel.replayCurrentStep()
        }
        .accessibilityIdentifier("cook-mode-replay-step")
        .accessibilityLabel("Replay step")
        .accessibilityHint("read this step aloud once")
    }

    /// The pacing control, surfaced from the old long-press menu as a visible
    /// tortoise/hare affordance: tap the hare to speed up, the tortoise to slow
    /// down. Both re-speak when Voice Mode is on (handled by the view model).
    private var speedButton: some View {
        HStack(spacing: DODSpacing.md) {
            Button {
                viewModel.slowDown()
            } label: {
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DODColor.accent)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("cook-mode-voice-slower")
            .accessibilityLabel("Slow down voice")

            Button {
                viewModel.speedUp()
            } label: {
                Image(systemName: "hare.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DODColor.accent)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("cook-mode-voice-faster")
            .accessibilityLabel("Speed up voice")
        }
    }

    // MARK: - Reusable button shapes

    private let centerDiameter: CGFloat = 72
    private let flankDiameter: CGFloat = 54

    private func flankButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DODColor.cream)
                .frame(width: flankDiameter, height: flankDiameter)
                .background(Circle().fill(DODColor.accent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func secondaryButton(
        symbol: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(DODColor.accent)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
