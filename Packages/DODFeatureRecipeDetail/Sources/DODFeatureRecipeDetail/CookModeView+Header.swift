import DODDesignSystem
import SwiftUI

/// Cook Mode header (DUT-325) — extracted from `CookModeView.swift` so that
/// file stays under the SwiftLint `file_length` cap.
///
/// Layout (DUT-325): a slim top row carrying **Done** (exit, leading) and the
/// voice-controls cluster (speaker + replay, trailing); then a header block
/// giving the recipe name room to breathe (larger, wraps to ~2 lines, full
/// width, no middle-truncation) with the step counter caption directly beneath
/// it. The step-counter logic + accessibility labels are unchanged from the
/// pre-DUT-325 `topBar`.
extension CookModeView {

    /// The full Cook Mode header: the action row + the name/counter block.
    var cookModeHeader: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            headerActionRow
            headerTitleBlock
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.top, DODSpacing.sm)
        .padding(.bottom, DODSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DODColor.surface)
    }

    /// Top row: Done (exit) on the leading edge, the voice-controls cluster on
    /// the trailing edge. No recipe name here — it gets its own full-width row
    /// below so it never has to share space with the controls.
    private var headerActionRow: some View {
        HStack(alignment: .center) {
            Button("Done") { close() }
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
                .accessibilityLabel("Exit Cook Mode")
            Spacer()
            voiceControls
        }
    }

    /// Recipe name (allowed to wrap to ~2 lines, full width, no truncation)
    /// with the step counter caption directly under it.
    private var headerTitleBlock: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xxs) {
            Text(viewModel.recipe.title)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(stepCounterLabel)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .monospacedDigit()
                .accessibilityLabel(stepCounterAccessibilityLabel)
        }
    }

    // MARK: - Voice-controls cluster (DUT-325)

    /// The grouped voice controls: the Voice Mode speaker toggle (long-press →
    /// Slower/Faster menu) beside a one-shot replay-current-step button. Voice
    /// controls render in `DODColor.accent`/`label` per the design language.
    private var voiceControls: some View {
        HStack(spacing: DODSpacing.md) {
            voiceModeToggle
            replayStepButton
        }
    }

    /// Voice Mode toggle (US-40 / AC-40.1) — a `speaker.wave.2` button that
    /// fills (`speaker.wave.2.fill`) when reading is on. Tap flips Voice Mode;
    /// turning it on immediately reads the current step (AC-40.2), off stops
    /// the reader. DUT-325 — **long-press** opens a Slower / Faster pacing menu
    /// that adjusts the TTS speed for the session.
    @ViewBuilder
    var voiceModeToggle: some View {
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
        .contextMenu { voiceSpeedMenu }
    }

    /// DUT-325 — the long-press speed menu attached to the speaker. Session-only
    /// pacing; the VM clamps each nudge and re-speaks while Voice Mode is on so
    /// the change is audible immediately.
    @ViewBuilder
    private var voiceSpeedMenu: some View {
        Button {
            viewModel.slowDown()
        } label: {
            Label("Slower", systemImage: "tortoise")
        }
        .accessibilityIdentifier("cook-mode-voice-slower")
        Button {
            viewModel.speedUp()
        } label: {
            Label("Faster", systemImage: "hare")
        }
        .accessibilityIdentifier("cook-mode-voice-faster")
    }

    /// DUT-325 — replay the current step (or the Done line) once, regardless of
    /// the Voice Mode toggle. Uses SF Symbol `arrow.trianglehead.counterclockwise`.
    @ViewBuilder
    private var replayStepButton: some View {
        Button {
            viewModel.replayCurrentStep()
        } label: {
            Image(systemName: "arrow.trianglehead.counterclockwise")
                .foregroundStyle(DODColor.accent)
        }
        .accessibilityIdentifier("cook-mode-replay-step")
        .accessibilityLabel("Replay step")
        .accessibilityHint("read this step aloud once")
    }

    // MARK: - Step counter (AC-7.2)

    var stepCounterLabel: String {
        if viewModel.isFinished { return "Done" }
        return "Step \(viewModel.currentStepIndex + 1) of \(viewModel.stepCount)"
    }

    var stepCounterAccessibilityLabel: String {
        if viewModel.isFinished { return "Cooking complete" }
        return "Step \(viewModel.currentStepIndex + 1) of \(viewModel.stepCount)"
    }
}
