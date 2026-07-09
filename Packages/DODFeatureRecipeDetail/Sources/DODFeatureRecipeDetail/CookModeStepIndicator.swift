import DODDesignSystem
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// DUT-596 (was DUT-582 / CL-315) — Cook Mode's slim brand progress bar, shown
/// at the bottom of the player (below the ingredients pull tab).
///
/// A single continuous progress bar (the old per-step "page dots" are gone: they
/// didn't scale to long recipes and read as clutter next to the transport). A
/// `surfaceDivider` track carries a `burntOrange` fill whose width is the
/// completion fraction, with a star glyph pinned to the trailing end — an outline
/// `star` while cooking, becoming a filled burnt-orange `star.fill` only on the
/// "All Done" page. Below it sits the "Step X of Y" caption ("Done" when
/// finished). Purely presentational — reads `currentStepIndex`, `stepCount`, and
/// `isFinished` off the view model.
struct CookModeStepIndicator: View {

    let viewModel: CookModeViewModel

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

    /// Diameter of the trailing star glyph, and the horizontal room reserved for
    /// it so the fill never runs under the star.
    private var starSize: CGFloat { isPad ? 24 : 18 }

    /// Height of the progress track, and the max width the whole indicator claims.
    private var barHeight: CGFloat { isPad ? 8 : 6 }
    private var indicatorMaxWidth: CGFloat { isPad ? 420 : 280 }
    private var counterFont: Font { isPad ? DODType.detail : DODType.caption }

    private var progress: CookModeProgress {
        CookModeProgress(
            currentStepIndex: viewModel.currentStepIndex,
            stepCount: viewModel.stepCount,
            isFinished: viewModel.isFinished
        )
    }

    var body: some View {
        VStack(spacing: DODSpacing.xs) {
            progressBar
            Text(progress.counterLabel)
                .dodFont(counterFont)
                .foregroundStyle(DODColor.labelSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.xs)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progress.accessibilityLabel)
    }

    // MARK: - Progress bar with trailing star

    private var progressBar: some View {
        let fraction = progress.fraction
        return HStack(spacing: DODSpacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DODColor.surfaceDivider)
                    Capsule()
                        .fill(DODColor.burntOrange)
                        .frame(width: max(barHeight, geo.size.width * fraction))
                }
            }
            .frame(height: barHeight)

            Image(systemName: progress.isFinished ? "star.fill" : "star")
                .font(.system(size: starSize * 0.8, weight: .semibold))
                .foregroundStyle(progress.isFinished ? DODColor.burntOrange : DODColor.surfaceDivider)
                .frame(width: starSize, height: starSize)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: indicatorMaxWidth)
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
