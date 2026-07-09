import DODDesignSystem
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// DUT-582 (CL-315) — Cook Mode's music/podcast-style transport bar.
///
/// A single row of circular brand-colored controls, laid out like a media
/// player: **Previous** and **Next** flank a large center **Voice play/pause**
/// button, with a secondary row underneath carrying **Replay** and a **speed**
/// control (the pacing menu, surfaced as a visible affordance).
///
/// This is a pure presentation layer over ``CookModeViewModel`` — it wires the
/// existing bindings (`goBack`/`goNext`, `togglePlayback`, `replayCurrentStep`,
/// `cycleVoiceSpeed`/`setVoiceSpeed`) and holds no state of its own. All controls
/// render on brand tokens (`burntOrange`/`accent`/`cream`); nothing renders grey.
///
/// Center semantics (DUT-583): a true **play / pause / resume** control driven by
/// `playbackState`. Idle → play glyph; tapping starts reading. Speaking → pause
/// glyph; tapping pauses in place (no restart). Paused → play glyph; tapping
/// resumes from where it left off. In the finished state it becomes a "Finish"
/// affordance that closes Cook Mode.
struct CookModePlayerControls: View {

    let viewModel: CookModeViewModel
    /// The step-change animation (nil under Reduce Motion), passed down from the
    /// host so Prev/Next animate consistently with the swipe gesture.
    let stepChangeAnimation: Animation?
    /// Invoked when the center button acts as "Finish" in the done state.
    let onFinish: () -> Void
    /// DUT-596 — called on ANY control interaction (transport, replay, speed) so
    /// the host can wake the auto-minimizing control panel and re-arm the idle
    /// timer. Defaults to a no-op for previews / hosts that don't wire it.
    var onInteract: () -> Void = {}
    /// DUT-599 — open the ingredients drawer. The ingredients access moved off
    /// the old bottom pull tab into the `carrot.fill` button in the secondary
    /// row. No-op default for previews.
    var onIngredients: () -> Void = {}

    /// DUT — iPad scales the transport up for the larger canvas. On iPad the
    /// glyphs, circles, speed pill, and spacing enlarge ~1.3–1.4×; on iPhone
    /// every size below returns the exact shipped value, so ALL iPhones render
    /// byte-identically. Gated on the DEVICE IDIOM (not the width class) so an
    /// iPhone Pro Max in landscape — which reports a `.regular` width class —
    /// keeps the iPhone sizes; only genuine iPads scale up. The idiom is fixed
    /// for the process, so reading it once here is fine.
    private var isPad: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

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
        HStack(spacing: transportSpacing) {
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
            flankButton(symbol: "arrow.backward", label: "Previous Step") {
                onInteract()
                withAnimation(stepChangeAnimation) { viewModel.goBack() }
            }
            .accessibilityIdentifier("cook-mode-previous")
        } else {
            // Reserve the slot so the center button stays centered on step 1.
            Color.clear.frame(width: flankDiameter, height: flankDiameter)
        }
    }

    private var nextButton: some View {
        flankButton(symbol: "arrow.forward", label: "Next Step") {
            onInteract()
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
                .font(.system(size: centerIconSize, weight: .bold))
                .foregroundStyle(DODColor.cream)
                // DUT-583 — crisp play↔pause swap; no lingering fade/delay.
                .contentTransition(.symbolEffect(.replace))
                .frame(width: centerDiameter, height: centerDiameter)
                .background(Circle().fill(DODColor.burntOrange))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cook-mode-voice-playpause")
        .accessibilityLabel(centerAccessibilityLabel)
        .accessibilityHint(centerAccessibilityHint)
        .accessibilityAddTraits(viewModel.isPlaying ? .isSelected : [])
    }

    private func centerAction() {
        onInteract()
        if viewModel.isFinished {
            onFinish()
            return
        }
        // DUT-583 — one call owns start / pause / resume (no "play then replay"
        // double-speak). Pause holds position; resume continues from there.
        viewModel.togglePlayback()
    }

    private var centerSymbol: String {
        if viewModel.isFinished { return "checkmark" }
        return viewModel.isPlaying ? "pause.fill" : "play.fill"
    }

    private var centerAccessibilityLabel: String {
        if viewModel.isFinished { return "Finish" }
        return viewModel.isPlaying ? "Pause voice" : "Play voice"
    }

    private var centerAccessibilityHint: String {
        if viewModel.isFinished { return "leave Cook Mode" }
        return viewModel.isPlaying ? "pause reading this step" : "read this step aloud"
    }

    // MARK: - Secondary row (Ingredients + Replay + speed)

    private var secondaryRow: some View {
        HStack(spacing: secondarySpacing) {
            Spacer(minLength: 0)
            ingredientsButton
            replayButton
            speedButton
            Spacer(minLength: 0)
        }
        .opacity(viewModel.isFinished ? 0 : 1)
        .disabled(viewModel.isFinished)
        .accessibilityHidden(viewModel.isFinished)
    }

    /// DUT-599 — ingredients access, a `carrot.fill` to the LEFT of Replay
    /// (replacing the old bottom pull tab). Opens the ingredients drawer.
    private var ingredientsButton: some View {
        secondaryButton(symbol: "carrot.fill", title: "Ingredients") {
            onInteract()
            onIngredients()
        }
        .accessibilityIdentifier("cook-mode-ingredients")
        .accessibilityLabel("Show ingredients")
        .accessibilityValue(
            "\(viewModel.checkedIngredientIDs.count) of \(viewModel.recipe.ingredients.count) checked"
        )
    }

    private var replayButton: some View {
        secondaryButton(symbol: "arrow.trianglehead.counterclockwise", title: "Replay") {
            onInteract()
            viewModel.replayCurrentStep()
        }
        .accessibilityIdentifier("cook-mode-replay-step")
        .accessibilityLabel("Replay step")
        .accessibilityHint("read this step aloud once")
    }

    /// DUT-583 — the pacing control as a single "1x" pill that shows the actual
    /// speed. A tap cycles up through the speeds and wraps from the top (2×)
    /// back to the bottom (0.5×); a long press opens a menu to pick an exact
    /// speed. Re-speaks when a step is actively reading (handled by the model).
    private var speedButton: some View {
        Button {
            onInteract()
            viewModel.cycleVoiceSpeed()
        } label: {
            Text(viewModel.voiceSpeedLabel)
                .dodFont(speedFont)
                .monospacedDigit()
                .foregroundStyle(DODColor.accent)
                .frame(minWidth: speedPillMinWidth, minHeight: speedPillMinHeight)
                .contentShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(DODColor.accent.opacity(0.6), lineWidth: speedPillStroke)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cook-mode-voice-speed")
        .accessibilityLabel("Playback speed")
        .accessibilityValue(viewModel.voiceSpeedLabel)
        .accessibilityHint("tap to change speed, touch and hold to pick one")
        .contextMenu { speedMenu }
    }

    @ViewBuilder
    private var speedMenu: some View {
        ForEach(VoiceReader.speedMultipliers, id: \.self) { speed in
            Button {
                viewModel.setVoiceSpeed(speed)
            } label: {
                if speed == viewModel.voiceSpeedMultiplier {
                    Label(CookModeViewModel.speedLabel(for: speed), systemImage: "checkmark")
                } else {
                    Text(CookModeViewModel.speedLabel(for: speed))
                }
            }
        }
    }

    // MARK: - Control sizing (iPad-scaled)
    //
    // DUT — compact (iPhone) returns the exact shipped literals; regular (iPad)
    // scales the transport glyphs + circles ~1.35–1.4×, and bumps the speed pill
    // and row spacing proportionally. Tap targets stay >=44pt on both.
    private var centerDiameter: CGFloat { isPad ? 100 : 72 }
    private var flankDiameter: CGFloat { isPad ? 74 : 54 }
    private var centerIconSize: CGFloat { isPad ? 42 : 30 }
    private var flankIconSize: CGFloat { isPad ? 30 : 22 }
    private var secondaryIconSize: CGFloat { isPad ? 27 : 20 }
    private var secondaryTapTarget: CGFloat { isPad ? 56 : 44 }
    private var speedPillMinWidth: CGFloat { isPad ? 76 : 56 }
    private var speedPillMinHeight: CGFloat { isPad ? 56 : 44 }
    private var speedPillStroke: CGFloat { isPad ? 2 : 1.5 }
    private var speedFont: Font { isPad ? DODType.displayMedium : DODType.bodyEmphasized }
    private var transportSpacing: CGFloat { isPad ? DODSpacing.xl : DODSpacing.lg }
    private var secondarySpacing: CGFloat { isPad ? 40 : DODSpacing.xl }

    // MARK: - Reusable button shapes

    private func flankButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: flankIconSize, weight: .semibold))
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
                .font(.system(size: secondaryIconSize, weight: .semibold))
                .foregroundStyle(DODColor.accent)
                .frame(minWidth: secondaryTapTarget, minHeight: secondaryTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
