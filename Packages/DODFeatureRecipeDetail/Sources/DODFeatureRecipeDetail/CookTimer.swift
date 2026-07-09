import DODDesignSystem
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Compact inline countdown timer offered by Cook Mode when a step's text
/// contains a parseable duration (see `StepTimerParser`). One-shot, visual only.
///
/// DUT-293/294 — a thin view over ``CookModeViewModel``'s per-step timer state
/// (keyed by step index): the countdown keeps running while you browse other
/// steps, one step never shows another's countdown, and the model reconciles the
/// Live Activity. The display self-ticks from the stored `endDate` via a
/// `TimelineView`, so it's correct even after the view was off screen.
///
/// DUT-582 (CL-315) — restyled as a player-style brand card: a big monospaced
/// countdown, a thin progress bar showing elapsed time, and circular
/// Start/Pause (`burntOrange`, cream glyph) + Reset (brand-tinted) controls. No
/// control renders grey — the old `labelSecondary`-tinted Reset moved to brand.
///
/// Lifecycle: the user taps Start (no auto-start); Pause freezes without
/// resetting; Reset returns to the original duration; at 00:00 the time turns
/// ``DODColor.accent`` and the completion haptic fires (from `CookModeView`).
struct CookTimer: View {

    let stepIndex: Int
    let totalSeconds: Int
    let viewModel: CookModeViewModel

    /// Gates the completion color/glyph transition — no motion when the user
    /// asked for reduced motion (mirrors `CookModeView` / `CookModeView+Controls`).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// DUT — iPad scales the Start/Pause + Reset circles up for the larger
    /// canvas; ALL iPhones keep the shipped 44pt buttons byte-for-byte. Gated on
    /// the DEVICE IDIOM (not the width class) so an iPhone Pro Max in landscape —
    /// which reports a `.regular` width class — stays iPhone-sized.
    private var isPad: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }
    private var buttonDiameter: CGFloat { isPad ? 56 : 44 }
    private var startIconSize: CGFloat { isPad ? 24 : 18 }
    private var resetIconSize: CGFloat { isPad ? 22 : 16 }
    private var resetStroke: CGFloat { isPad ? 2 : 1.5 }

    init(stepIndex: Int, duration: Duration, viewModel: CookModeViewModel) {
        self.stepIndex = stepIndex
        self.totalSeconds = max(Int(duration.components.seconds), 0)
        self.viewModel = viewModel
    }

    /// Current state for this step — a fresh idle timer until the user starts one.
    private var timer: CookStepTimer {
        viewModel.timer(forStep: stepIndex) ?? CookStepTimer(totalSeconds: totalSeconds)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let snapshot = timer
            card(
                remaining: snapshot.remaining(at: context.date),
                isRunning: snapshot.isRunning,
                didComplete: snapshot.didComplete
            )
        }
    }

    private func card(remaining: Int, isRunning: Bool, didComplete: Bool) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            HStack(alignment: .center, spacing: DODSpacing.sm) {
                Image(systemName: "timer")
                    .foregroundStyle(didComplete ? DODColor.accent : DODColor.burntOrange)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(formatted(remaining))
                    .dodFont(DODType.displayLarge)
                    .monospacedDigit()
                    .foregroundStyle(didComplete ? DODColor.accent : DODColor.label)
                    .accessibilityLabel(accessibilityTimeLabel(remaining))
                Spacer(minLength: 0)
                controls(isRunning: isRunning, didComplete: didComplete)
            }
            progressBar(remaining: remaining, didComplete: didComplete)
        }
        .padding(DODSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .strokeBorder(DODColor.burntOrange.opacity(0.25), lineWidth: 1)
        )
        // Ease the hard color+glyph cut when the countdown hits 00:00
        // (mirrors `IngredientCheckRow`); no motion under Reduce Motion.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: didComplete)
        .accessibilityElement(children: .contain)
    }

    /// Thin brand progress bar showing elapsed fraction of the countdown.
    private func progressBar(remaining: Int, didComplete: Bool) -> some View {
        let elapsed =
            totalSeconds > 0
            ? Double(totalSeconds - remaining) / Double(totalSeconds) : (didComplete ? 1 : 0)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DODColor.surfaceDivider)
                Capsule()
                    .fill(didComplete ? DODColor.accent : DODColor.burntOrange)
                    .frame(width: max(0, geo.size.width * min(max(elapsed, 0), 1)))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func controls(isRunning: Bool, didComplete: Bool) -> some View {
        HStack(spacing: DODSpacing.sm) {
            Button {
                if didComplete { return }
                if isRunning {
                    viewModel.pauseTimer(forStep: stepIndex)
                } else {
                    viewModel.startOrResumeTimer(forStep: stepIndex, totalSeconds: totalSeconds)
                }
            } label: {
                Image(systemName: didComplete ? "checkmark" : (isRunning ? "pause.fill" : "play.fill"))
                    .font(.system(size: startIconSize, weight: .bold))
                    .foregroundStyle(DODColor.cream)
                    .frame(width: buttonDiameter, height: buttonDiameter)
                    .background(Circle().fill(DODColor.burntOrange))
            }
            .buttonStyle(.plain)
            .disabled(didComplete)
            .accessibilityLabel(didComplete ? "Timer complete" : isRunning ? "Pause timer" : "Start timer")

            Button {
                viewModel.resetTimer(forStep: stepIndex)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: resetIconSize, weight: .semibold))
                    .foregroundStyle(DODColor.accent)
                    .frame(width: buttonDiameter, height: buttonDiameter)
                    .overlay(Circle().strokeBorder(DODColor.accent, lineWidth: resetStroke))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset timer")
        }
        // Light selection tick on Start/Pause (matches the app's `.selection`
        // vocabulary for discrete controls, e.g. Cook Mode step changes).
        // Suppressed at 00:00 so it doesn't double up with the `.success`
        // completion haptic `CookModeView` already fires on `timerCompletionTick`.
        .sensoryFeedback(trigger: isRunning) { _, _ in
            didComplete ? nil : .selection
        }
    }

    private func formatted(_ remaining: Int) -> String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private func accessibilityTimeLabel(_ remaining: Int) -> String {
        let minutes = remaining / 60
        let seconds = remaining % 60
        // DUT-644: singular/plural units — "1 minute" / "2 minutes", "1 second"
        // / "30 seconds" — so VoiceOver never reads "1 minutes".
        let minuteWord = minutes == 1 ? "minute" : "minutes"
        let secondWord = seconds == 1 ? "second" : "seconds"
        if minutes > 0 && seconds > 0 {
            return "\(minutes) \(minuteWord) \(seconds) \(secondWord) remaining"
        }
        if minutes > 0 { return "\(minutes) \(minuteWord) remaining" }
        return "\(seconds) \(secondWord) remaining"
    }
}
