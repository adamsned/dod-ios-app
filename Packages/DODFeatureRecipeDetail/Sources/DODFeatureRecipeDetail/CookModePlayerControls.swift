import DODDesignSystem
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Cook Mode's transport — a single horizontal row, redesigned so the whole
/// control cluster is short (one row, not two) and the play/pause button sits
/// dead-center.
///
/// Five controls, left to right: **Replay · Previous · Play/Pause · Next ·
/// Speed**. Ingredients moved OUT of the transport up to the hero (see
/// `CookModeView.cookModeTopBar`), which is what frees the center slot for Play.
///
/// DUT-1392 — the controls are big and packed together as one centered cluster
/// (they used to be spread across five full-width slots). Replay and Speed share
/// one width so Play stays dead-center. Previous / Next are cream arrows on
/// orange circles, the same style as the minimized nav, with Play the largest
/// circle. The gaps shrink (down to `xxs`) on narrow phones so the cluster
/// always fits.
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
            replayButton
            gap
            previousButton
            gap
            centerButton
            gap
            nextButton
            gap
            speedButton
        }
        .padding(.horizontal, DODSpacing.xs)
        .padding(.bottom, DODSpacing.xs)
        .frame(maxWidth: .infinity)
        .background(DODColor.surface)
    }

    /// DUT-1392 — the space between two controls: `clusterGap` when there's room,
    /// shrinking toward `xxs` on a narrow phone so the cluster never overflows.
    private var gap: some View {
        Spacer(minLength: DODSpacing.xxs).frame(maxWidth: clusterGap)
    }

    // MARK: - Side controls (plain glyphs)

    private var replayButton: some View {
        glyphButton(symbol: "arrow.trianglehead.counterclockwise", label: "Replay step") {
            onInteract()
            viewModel.replayCurrentStep()
        }
        .frame(width: sideWidth)
        .accessibilityIdentifier("cook-mode-replay-step")
        .accessibilityHint("read this step aloud once")
    }

    @ViewBuilder
    private var previousButton: some View {
        if showsPrevious {
            CookModeNavCircleButton(
                symbol: "arrow.backward",
                label: "Previous Step",
                diameter: navDiameter,
                iconSize: navIconSize
            ) {
                onInteract()
                withAnimation(stepChangeAnimation) { viewModel.goBack() }
            }
            .accessibilityIdentifier("cook-mode-previous")
        } else {
            // Reserve the slot so the center button stays centered on step 1.
            Color.clear.frame(width: navDiameter, height: navDiameter)
        }
    }

    private var nextButton: some View {
        CookModeNavCircleButton(
            symbol: "arrow.forward",
            label: "Next Step",
            diameter: navDiameter,
            iconSize: navIconSize
        ) {
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
                .frame(width: sideWidth, height: speedPillHeight)
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
    // DUT-1392 — big, thumb-sized controls on both, scaled up again on iPad.
    // DUT-1394 — iPhone trimmed back a little (was Play 84 / Prev-Next 64 /
    // sides 56), about halfway to the original sizes. Every tap target is
    // still over 44pt. iPhone max cluster width (gaps at `clusterGap`) is
    // 342pt, so it fits a 375pt phone without the gaps shrinking.
    private var centerDiameter: CGFloat { isPad ? 116 : 74 }
    private var centerIconSize: CGFloat { isPad ? 48 : 30 }
    private var navDiameter: CGFloat { isPad ? 88 : 56 }
    private var navIconSize: CGFloat { isPad ? 34 : 23 }
    /// Replay + Speed share this width so Play sits dead-center.
    private var sideWidth: CGFloat { isPad ? 76 : 50 }
    private var glyphIconSize: CGFloat { isPad ? 34 : 24 }
    private var glyphTapTarget: CGFloat { isPad ? 76 : 50 }
    private var speedPillHeight: CGFloat { isPad ? 60 : 40 }
    private var clusterGap: CGFloat { isPad ? 28 : 14 }
    private var speedPillStroke: CGFloat { isPad ? 2 : 1.5 }
    private var speedFont: Font { isPad ? DODType.displayMedium : DODType.bodyEmphasized }

    // MARK: - Reusable side-glyph button

    /// A plain (unfilled) burnt-orange glyph button with a >=44pt tap target,
    /// used for Replay (Previous / Next are ``CookModeNavCircleButton``s).
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

/// DUT-1392 — the Previous / Next control: a cream arrow on a filled orange
/// circle. One style for the expanded transport AND the minimized nav (only the
/// size differs), so the two states read as the same buttons.
struct CookModeNavCircleButton: View {

    let symbol: String
    let label: String
    let diameter: CGFloat
    let iconSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(DODColor.cream)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(DODColor.burntOrange))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
