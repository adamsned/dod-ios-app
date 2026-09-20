import DODDesignSystem
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Cook Mode's transport — a single horizontal row, redesigned so the whole
/// control cluster is short (one row, not two) and the play/pause button sits
/// dead-center.
///
/// Five equal-width slots, left to right: **Replay · Previous · Play/Pause ·
/// Next · Speed**. Equal slots put the center Play button exactly under the ^
/// grabber. Ingredients moved OUT of the transport up to the hero (see
/// `CookModeView.cookModeTopBar`), which is what frees the center slot for Play.
/// Only the center control is a filled circle (podcast-transport style); the
/// side controls are plain burnt-orange glyphs.
///
/// Pure presentation over ``CookModeViewModel`` — it wires the existing bindings
/// (`goBack`/`goNext`, `togglePlayback`, `replayCurrentStep`, `cycleVoiceSpeed`/
/// `setVoiceSpeed`) and holds no state.
///
/// Center semantics (DUT-583): a true play / pause / resume control driven by
/// `playbackState`; in the finished state it becomes a "Finish" checkmark that
/// closes Cook Mode.
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

    /// DUT — iPad scales the transport up for the larger canvas. On iPhone every
    /// size below returns the exact iPhone value, so all iPhones render
    /// identically. Gated on the DEVICE IDIOM (not the width class) so an iPhone
    /// Pro Max in landscape (`.regular` width) keeps the iPhone sizes.
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
        HStack(spacing: 0) {
            slot { replayButton }
            slot { previousButton }
            slot { centerButton }
            slot { nextButton }
            slot { speedButton }
        }
        .padding(.horizontal, DODSpacing.sm)
        .padding(.bottom, DODSpacing.xs)
        .frame(maxWidth: .infinity)
        .background(DODColor.surface)
    }

    /// One equal-width column. Equal slots keep the center Play button aligned to
    /// the row's center regardless of the side controls' widths.
    private func slot<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().frame(maxWidth: .infinity)
    }

    // MARK: - Side controls (plain glyphs)

    private var replayButton: some View {
        glyphButton(symbol: "arrow.trianglehead.counterclockwise", label: "Replay step") {
            onInteract()
            viewModel.replayCurrentStep()
        }
        .accessibilityIdentifier("cook-mode-replay-step")
        .accessibilityHint("read this step aloud once")
    }

    @ViewBuilder
    private var previousButton: some View {
        if showsPrevious {
            glyphButton(symbol: "arrow.backward", label: "Previous Step") {
                onInteract()
                withAnimation(stepChangeAnimation) { viewModel.goBack() }
            }
            .accessibilityIdentifier("cook-mode-previous")
        } else {
            // Reserve the slot so the center button stays centered on step 1.
            Color.clear.frame(width: glyphTapTarget, height: glyphTapTarget)
        }
    }

    private var nextButton: some View {
        glyphButton(symbol: "arrow.forward", label: "Next Step") {
            onInteract()
            withAnimation(stepChangeAnimation) { viewModel.goNext() }
        }
        .accessibilityIdentifier("cook-mode-next")
        // Advancing past the last step is handled by the view model (isFinished);
        // hide Next once fully finished so the row reads as complete.
        .opacity(viewModel.isFinished ? 0 : 1)
        .disabled(viewModel.isFinished)
    }

    // MARK: - Center (Play / Pause / Finish)

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

    // MARK: - Speed

    /// DUT-583 — the pacing control as a single pill showing the actual speed. A
    /// tap cycles up through the podcast/audiobook speeds (soft wrap at the top);
    /// a long press opens a menu to pick an exact speed.
    private var speedButton: some View {
        Button {
            onInteract()
            viewModel.cycleVoiceSpeed()
        } label: {
            Text(viewModel.voiceSpeedLabel)
                .dodFont(speedFont)
                .monospacedDigit()
                .foregroundStyle(DODColor.accent)
                .frame(minWidth: speedPillMinWidth, minHeight: glyphTapTarget)
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
    // iPhone returns the exact literals; iPad scales the center circle + glyphs
    // up for the larger canvas. Tap targets stay >=44pt on both.
    private var centerDiameter: CGFloat { isPad ? 92 : 64 }
    private var centerIconSize: CGFloat { isPad ? 40 : 27 }
    private var glyphIconSize: CGFloat { isPad ? 30 : 24 }
    private var glyphTapTarget: CGFloat { isPad ? 56 : 44 }
    private var speedPillMinWidth: CGFloat { isPad ? 72 : 52 }
    private var speedPillStroke: CGFloat { isPad ? 2 : 1.5 }
    private var speedFont: Font { isPad ? DODType.displayMedium : DODType.bodyEmphasized }

    // MARK: - Reusable side-glyph button

    /// A plain (unfilled) burnt-orange glyph button with a >=44pt tap target,
    /// used for Replay / Previous / Next so only the center Play reads as filled.
    private func glyphButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: glyphIconSize, weight: .semibold))
                .foregroundStyle(DODColor.burntOrange)
                .frame(width: glyphTapTarget, height: glyphTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
