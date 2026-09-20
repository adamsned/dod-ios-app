import DODDesignSystem
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Cook Mode's slim brand progress footer (redesigned) — a single continuous
/// progress bar with the "Step X of Y" counter INLINE at its trailing end.
///
/// A `surfaceDivider` track carries a `burntOrange` fill whose width is the
/// completion fraction. The trailing slot shows the step counter while cooking
/// and TRANSFORMS into a filled gold star on the "All Done" page — so the star
/// (the completion reward) lives here via a transform rather than taking a
/// permanent slot. Purely presentational — reads `currentStepIndex`,
/// `stepCount`, and `isFinished` off the view model.
struct CookModeStepIndicator: View {

    let viewModel: CookModeViewModel

    /// Constitution §7 — drop the counter→star transform animation under Reduce
    /// Motion (the swap still happens, just without the scale/pop).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// DUT — iPad enlarges the progress bar, star, width, and caption for the
    /// larger canvas; ALL iPhones keep the shipped sizes byte-for-byte. Gated on
    /// the DEVICE IDIOM (not the width class) so an iPhone Pro Max in landscape —
    /// which reports a `.regular` width class — stays iPhone-sized.
    private var isPad: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

    /// Size of the trailing gold star (Done state).
    private var starSize: CGFloat { isPad ? 24 : 18 }

    /// Height of the progress track.
    private var barHeight: CGFloat { isPad ? 8 : 6 }
    private var counterFont: Font { isPad ? DODType.detail : DODType.caption }

    private var progress: CookModeProgress {
        CookModeProgress(
            currentStepIndex: viewModel.currentStepIndex,
            stepCount: viewModel.stepCount,
            isFinished: viewModel.isFinished
        )
    }

    var body: some View {
        HStack(spacing: DODSpacing.sm) {
            progressBar
            trailingStatus
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.xs)
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: progress.isFinished)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progress.accessibilityLabel)
    }

    /// The full-width progress track + burnt-orange fill.
    private var progressBar: some View {
        let fraction = progress.fraction
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DODColor.surfaceDivider)
                Capsule()
                    .fill(DODColor.burntOrange)
                    .frame(width: max(barHeight, geo.size.width * fraction))
            }
        }
        .frame(height: barHeight)
        .frame(maxWidth: .infinity)
    }

    /// The trailing slot: the "Step X of Y" counter while cooking, which
    /// transforms into a filled burnt-orange star on the Done page (the star
    /// lives here via a transform rather than taking a permanent slot). Orange
    /// (not gold) so it matches the progress-bar fill + the rest of the transport.
    @ViewBuilder
    private var trailingStatus: some View {
        if progress.isFinished {
            Image(systemName: "star.fill")
                .font(.system(size: starSize, weight: .semibold))
                .foregroundStyle(DODColor.burntOrange)
                .transition(.scale.combined(with: .opacity))
                .accessibilityHidden(true)
        } else {
            Text(progress.counterLabel)
                .dodFont(counterFont)
                .foregroundStyle(DODColor.labelSecondary)
                .monospacedDigit()
                .fixedSize()
                .transition(.opacity)
        }
    }
}

/// DUT-596 — the pure progress model behind ``CookModeStepIndicator``. Extracted
/// so the fraction, the star-filled decision, and the caption/accessibility copy
/// are unit-testable without booting SwiftUI.
struct CookModeProgress: Equatable {

    let currentStepIndex: Int
    let rawStepCount: Int
    let isFinished: Bool

    init(currentStepIndex: Int, stepCount: Int, isFinished: Bool) {
        self.currentStepIndex = currentStepIndex
        self.rawStepCount = stepCount
        self.isFinished = isFinished
    }

    /// Step count clamped to at least 1 so the fraction / caption never divide
    /// by zero on a recipe with no parsed instructions.
    var stepCount: Int { max(rawStepCount, 1) }

    /// The 0-based active index, clamped into range and pinned to the last step
    /// when finished so the bar reads fully complete.
    var activeIndex: Int {
        if isFinished { return stepCount - 1 }
        return min(max(currentStepIndex, 0), stepCount - 1)
    }

    /// Completion fraction in `0...1`: `(activeIndex + 1) / stepCount` while
    /// cooking, `1.0` when finished. The star fills at `1.0`.
    var fraction: Double {
        isFinished ? 1 : Double(activeIndex + 1) / Double(stepCount)
    }

    var counterLabel: String {
        isFinished ? "Done" : "Step \(activeIndex + 1) of \(stepCount)"
    }

    var accessibilityLabel: String {
        isFinished ? "Cooking complete" : "Step \(activeIndex + 1) of \(stepCount)"
    }
}
