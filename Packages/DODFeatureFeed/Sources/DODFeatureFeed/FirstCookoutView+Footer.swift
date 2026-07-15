import DODDesignSystem
import DODSupport
import SwiftUI

/// The paged-flow footer for ``FirstCookoutView`` — Cook Mode's transport style
/// (DUT-324 → CL-315 parity). Extracted into its own file so both it and
/// `+Stages.swift` stay under the SwiftLint length caps.
extension FirstCookoutView {

    /// Cook Mode's mini transport: a pair of small equal circular Prev/Next
    /// buttons, with a slim burnt-orange progress bar + "Step X of Y" caption
    /// BELOW them. Replaces the old text-"Next" + corner-"Back" + page-dots
    /// layout so the whole guided flow reads like Cook Mode's mini controls.
    var controls: some View {
        VStack(spacing: DODSpacing.sm) {
            transportRow
            progressIndicator
        }
    }

    /// The pure page-progress model (reused from the shared ``StepProgress``):
    /// the guided flow's pages are the "steps", intro through celebration.
    private var pageProgress: StepProgress {
        StepProgress(currentIndex: index, count: lastIndex + 1)
    }

    /// Cook-Mode-style progress: a slim burnt-orange bar on a `surfaceDivider`
    /// track with a trailing star (filled only on the final page), and a
    /// "Step X of Y" caption — mirroring `CookModeStepIndicator`.
    private var progressIndicator: some View {
        VStack(spacing: DODSpacing.xs) {
            HStack(spacing: DODSpacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DODColor.surfaceDivider)
                        Capsule()
                            .fill(DODColor.burntOrange)
                            .frame(width: max(6, geo.size.width * pageProgress.fraction))
                    }
                }
                .frame(height: 6)
                Image(systemName: pageProgress.isLast ? "star.fill" : "star")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        pageProgress.isLast ? DODColor.burntOrange : DODColor.surfaceDivider
                    )
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: 280)
            Text(pageProgress.caption)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pageProgress.accessibilityLabel)
    }

    /// Cook Mode's mini transport: two small equal circular buttons — Previous
    /// (dimmed + disabled on the intro, nothing to go back to) and Advance (a
    /// forward arrow through the flow, becoming a checkmark on the final page,
    /// which logs the cook then dismisses). Both render on brand tokens, never
    /// grey — mirroring `CookModePlayerControls`.
    private var transportRow: some View {
        HStack(spacing: DODSpacing.lg) {
            Spacer(minLength: 0)
            previousButton
            advanceButton
            Spacer(minLength: 0)
        }
    }

    private var buttonDiameter: CGFloat { 48 }

    private var previousButton: some View {
        Button {
            index -= 1
        } label: {
            transportGlyph("arrow.backward")
        }
        .buttonStyle(.plain)
        // Dim (not grey) + disable on the intro; there's no prior page.
        .opacity(index > 0 ? 1 : 0.35)
        .disabled(index == 0)
        .accessibilityIdentifier("first-cookout-previous")
        .accessibilityLabel("Back")
        .accessibilityHidden(index == 0)
    }

    private var advanceButton: some View {
        Button {
            if index >= lastIndex {
                logCookIfNeeded()
                dismiss()
            } else {
                index += 1
            }
        } label: {
            transportGlyph(index >= lastIndex ? "checkmark" : "arrow.forward")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("first-cookout-advance")
        .accessibilityLabel(advanceAccessibilityLabel)
    }

    private func transportGlyph(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(DODColor.cream)
            .frame(width: buttonDiameter, height: buttonDiameter)
            .background(Circle().fill(DODColor.accent))
    }

    private var advanceAccessibilityLabel: String {
        if index == 0 { return "Start cooking" }
        if index >= lastIndex { return "Done" }
        return "Next"
    }
}
