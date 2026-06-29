import DODDesignSystem
import SwiftUI

/// Compact inline countdown timer offered by Cook Mode when a step's text
/// contains a parseable duration (see `StepTimerParser`). One-shot, visual only.
///
/// DUT-293/294 — a thin view over ``CookModeViewModel``'s per-step timer state
/// (keyed by step index): the countdown keeps running while you browse other
/// steps, one step never shows another's countdown, and the model reconciles the
/// Live Activity. The display self-ticks from the stored `endDate` via a
/// `TimelineView`, so it's correct even after the view was off screen.
///
/// Lifecycle: the user taps Start (no auto-start); Pause freezes without
/// resetting; Reset returns to the original duration; at 00:00 the time turns
/// ``DODColor.accent`` and the completion haptic fires (from `CookModeView`).
struct CookTimer: View {

    let stepIndex: Int
    let totalSeconds: Int
    let viewModel: CookModeViewModel

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
            row(
                remaining: snapshot.remaining(at: context.date),
                isRunning: snapshot.isRunning,
                didComplete: snapshot.didComplete
            )
        }
    }

    private func row(remaining: Int, isRunning: Bool, didComplete: Bool) -> some View {
        HStack(spacing: DODSpacing.sm) {
            Image(systemName: "timer")
                .foregroundStyle(didComplete ? DODColor.accent : DODColor.label)
                .font(.title3)
                .accessibilityHidden(true)
            Text(formatted(remaining))
                .dodFont(DODType.displayMedium)
                .monospacedDigit()
                .foregroundStyle(didComplete ? DODColor.accent : DODColor.label)
                .accessibilityLabel(accessibilityTimeLabel(remaining))
                .frame(minWidth: 88, alignment: .leading)
            Spacer(minLength: 0)
            controls(isRunning: isRunning, didComplete: didComplete)
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func controls(isRunning: Bool, didComplete: Bool) -> some View {
        HStack(spacing: DODSpacing.xs) {
            Button(isRunning ? "Pause" : (didComplete ? "Done" : "Start")) {
                if didComplete { return }
                if isRunning {
                    viewModel.pauseTimer(forStep: stepIndex)
                } else {
                    viewModel.startOrResumeTimer(forStep: stepIndex, totalSeconds: totalSeconds)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(DODColor.accent)
            .disabled(didComplete)
            .accessibilityLabel(isRunning ? "Pause timer" : "Start timer")

            Button("Reset") { viewModel.resetTimer(forStep: stepIndex) }
                .buttonStyle(.bordered)
                .tint(DODColor.labelSecondary)
                .accessibilityLabel("Reset timer")
        }
    }

    private func formatted(_ remaining: Int) -> String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private func accessibilityTimeLabel(_ remaining: Int) -> String {
        let minutes = remaining / 60
        let seconds = remaining % 60
        if minutes > 0 && seconds > 0 { return "\(minutes) minutes \(seconds) seconds remaining" }
        if minutes > 0 { return "\(minutes) minutes remaining" }
        return "\(seconds) seconds remaining"
    }
}
