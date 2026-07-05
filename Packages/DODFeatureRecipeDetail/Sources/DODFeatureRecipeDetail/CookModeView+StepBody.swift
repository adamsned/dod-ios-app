import DODDesignSystem
import DODDomain
import DODSupport
import SwiftUI

/// The large step / finished-state body for ``CookModeView`` plus the
/// DUT-401 VoiceOver announcement helpers, extracted here so the main
/// `CookModeView.swift` stays under the SwiftLint `file_length` /
/// `type_body_length` caps.
extension CookModeView {

    // MARK: - Step body (AC-7.2 large step, AC-7.4 finished state)

    @ViewBuilder
    var stepBody: some View {
        if viewModel.isFinished {
            doneCard
        } else if let step = viewModel.currentStep {
            stepCard(step)
        }
    }

    private func stepCard(_ step: RecipeInstruction) -> some View {
        // DUT-245 — apply the temperature-unit preference at display time, like
        // Recipe Detail does, so the step reads in the user's chosen unit.
        let displayText = convertedStepText(step.text)
        // DUT-583 — "now playing" treatment: just the prominent step text. The
        // "STEP N" eyebrow is gone — the bottom paged indicator ("Step X of Y"
        // under the dots) is the single source of position, so a second counter
        // above the step was redundant.
        return VStack(alignment: .leading, spacing: DODSpacing.md) {
            Text(displayText)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
                .lineSpacing(DODSpacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let duration = StepTimerParser.firstDuration(in: step.text) {
                CookTimer(
                    stepIndex: viewModel.currentStepIndex,
                    duration: duration,
                    viewModel: viewModel
                )
            }
            heatCoachShortcut(for: step)
        }
        .padding(.horizontal, DODSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step.step). \(displayText)")
    }

    /// T-912 / DUT-551 (CL-306) — a compact "Open Heat Coach" shortcut, shown
    /// only on **heat-related** steps and only when the host wired
    /// `heatCoachSheet`. A tab switch would be invisible under Cook Mode's
    /// full-screen cover, so the tap presents Heat Coach as a sheet OVER the
    /// cover (`isHeatCoachPresented`). Hidden on non-heat steps and on hosts /
    /// previews that don't wire hub routing (same seam as `onLogCook`).
    @ViewBuilder
    private func heatCoachShortcut(for step: RecipeInstruction) -> some View {
        if heatCoachSheet != nil, Self.stepIsHeatRelated(step.text) {
            Button {
                isHeatCoachPresented = true
            } label: {
                Label("Open Heat Coach", systemImage: "thermometer.medium")
                    .dodFont(DODType.bodyEmphasized)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DODColor.burntOrange)
            .accessibilityIdentifier("cook-mode-heat-coach")
        }
    }

    /// Whether a step's text is about heat — it carries an explicit-unit
    /// temperature (via ``TemperatureConverter/fahrenheitValues(in:)``) OR one of
    /// a small set of coal / fire keywords. Case-insensitive substring match.
    nonisolated static func stepIsHeatRelated(_ text: String) -> Bool {
        if !TemperatureConverter.fahrenheitValues(in: text).isEmpty { return true }
        let haystack = text.lowercased()
        return heatKeywords.contains(where: haystack.contains)
    }

    /// Coal / fire language that flags a step as heat-related even without an
    /// explicit temperature (e.g. "arrange the coals", "let the briquettes ash
    /// over", "preheat the oven").
    private nonisolated static let heatKeywords = [
        "coal", "briquette", "preheat", "pre-heat", "oven temp", "charcoal",
    ]

    /// DUT-245 — map a step's text through the temperature converter for the
    /// resolved preference (`nil` → unchanged). Mirrors
    /// `RecipeDetailView+Sections.convertedStepText`.
    func convertedStepText(_ text: String) -> String {
        guard let unit = TemperatureConverter.resolvedUnit(fromRawValue: temperatureUnitRaw)
        else { return text }
        return TemperatureConverter.converting(text, to: unit)
    }

    private var doneCard: some View {
        // DUT-583 — the celebratory line IS the icon now; the big
        // `checkmark.seal.fill` was redundant with the center transport button,
        // which already becomes a checkmark in the finished state.
        VStack(alignment: .center, spacing: DODSpacing.md) {
            Text("All Done, Enjoy!")
                .dodFont(DODType.displayLarge)
                .foregroundStyle(DODColor.label)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
            // DUT-596 — the "log this cook" CTA now leads the exit hint (was
            // below it), so the primary celebratory action is what the eye lands
            // on first and the "tap the checkmark" instruction reads as the
            // quieter follow-up.
            logCookButton
            Text("Tap the checkmark below to leave Cook Mode.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, DODSpacing.md)
    }

    /// DUT-596 — a comfortable fixed width for the Done-card journal CTA so it
    /// reads taller/skinnier (centered) rather than stretching full-bleed.
    private var logCookButtonWidth: CGFloat { 220 }

    /// DUT-326 — a clear, optional CTA on the Done card to save this cook to
    /// the Cooking Journal (photo + caption). Hidden when no `onLogCook` sink
    /// is wired (e.g. previews / hosts that haven't opted in). Logging here
    /// records a real completed cook and counts toward rank — intentional.
    @ViewBuilder
    private var logCookButton: some View {
        if onLogCook != nil {
            Button {
                isJournalLogPresented = true
            } label: {
                // DUT-596 — skinnier/taller: a constrained centered width (not
                // full-bleed) with extra vertical padding so the CTA reads as a
                // deliberate pill rather than a wide bar.
                Label("Add to Cooking Journal", systemImage: "camera.fill")
                    .multilineTextAlignment(.center)
                    .frame(width: logCookButtonWidth)
                    .padding(.vertical, DODSpacing.sm)
            }
            .dodProminentButton()
            .tint(DODColor.accent)
            .padding(.top, DODSpacing.sm)
            .accessibilityIdentifier("cook-mode-log-cook")
            .accessibilityLabel("Add this cook to your Cooking Journal")
        }
    }

    // MARK: - VoiceOver announcements (DUT-401)

    /// Post a VoiceOver announcement for a Cook Mode state change. A no-op when
    /// VoiceOver isn't running (the notification is simply dropped), so it never
    /// affects sighted users.
    func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    /// Announce the step the user just landed on, in the resolved temperature
    /// unit (matching the on-screen text), or the completion line in the Done
    /// state.
    ///
    /// DUT-441: while Voice Mode is on, the step change already speaks the full
    /// body through `speakCurrentStep()` — announcing it too would read the
    /// text twice over itself. Announce only a short position cue then, so a
    /// VoiceOver user still hears where they landed without the overlap.
    func announceCurrentStep() {
        if viewModel.isFinished {
            announce(viewModel.isVoiceModeEnabled ? "Done" : "All done. Tap Finish to leave Cook Mode.")
        } else if let step = viewModel.currentStep {
            if viewModel.isVoiceModeEnabled {
                announce("Step \(step.step)")
            } else {
                announce("Step \(step.step). \(convertedStepText(step.text))")
            }
        }
    }
}
