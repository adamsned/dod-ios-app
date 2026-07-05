import DODDesignSystem
import SwiftUI

/// DUT-582 (CL-315) — Cook Mode's paged progress indicator, shown at the bottom
/// of the player (the step counter left the top bar).
///
/// A media-player "page dots" affordance: one brand-colored dot per step with
/// the current step filled, plus a "Step X of Y" caption. Recipes with many
/// steps can't fit a dot each, so past a threshold it degrades to a slim brand
/// progress bar (fraction = `(currentStepIndex + 1) / stepCount`) with the same
/// caption. Purely presentational — reads `currentStepIndex`, `stepCount`, and
/// `isFinished` off the view model.
struct CookModeStepIndicator: View {

    let viewModel: CookModeViewModel

    /// Above this many steps, dots stop fitting cleanly on a phone width, so we
    /// fall back to the progress bar.
    private let dotThreshold = 12

    private var stepCount: Int { max(viewModel.stepCount, 1) }

    /// The 0-based "active" index, clamped into range and pinned to the last
    /// step when finished so the indicator reads fully complete.
    private var activeIndex: Int {
        if viewModel.isFinished { return stepCount - 1 }
        return min(max(viewModel.currentStepIndex, 0), stepCount - 1)
    }

    /// Completion fraction for the progress-bar fallback (1.0 when finished).
    private var fraction: Double {
        viewModel.isFinished ? 1 : Double(activeIndex + 1) / Double(stepCount)
    }

    var body: some View {
        VStack(spacing: DODSpacing.xs) {
            if stepCount > dotThreshold {
                progressBar
            } else {
                dots
            }
            Text(counterLabel)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.xs)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(counterAccessibilityLabel)
    }

    // MARK: - Dots

    private var dots: some View {
        HStack(spacing: DODSpacing.xs) {
            ForEach(0..<stepCount, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? DODColor.burntOrange : DODColor.surfaceDivider)
                    .frame(
                        width: index == activeIndex ? 10 : 7,
                        height: index == activeIndex ? 10 : 7
                    )
            }
        }
    }

    // MARK: - Progress bar (many-step fallback)

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DODColor.surfaceDivider)
                Capsule()
                    .fill(DODColor.burntOrange)
                    .frame(width: max(6, geo.size.width * fraction))
            }
        }
        .frame(height: 6)
        .frame(maxWidth: 240)
    }

    // MARK: - Labels

    private var counterLabel: String {
        if viewModel.isFinished { return "Done" }
        return "Step \(activeIndex + 1) of \(stepCount)"
    }

    private var counterAccessibilityLabel: String {
        if viewModel.isFinished { return "Cooking complete" }
        return "Step \(activeIndex + 1) of \(stepCount)"
    }
}
