import DODDesignSystem
import DODSupport
import Foundation
import SwiftUI

/// DUT-1392 — what Cook Mode's floating tool dock shows for the current step.
///
/// The dock floats just above the player controls (and rides up and down with
/// them as they minimize and expand), so the step's tools sit by the thumb
/// instead of inside the step text:
/// - the current step's timer, when the step names a duration,
/// - a timer still RUNNING on another step (the soonest to finish), so leaving a
///   step never hides its countdown, with a jump back to that step,
/// - the Heat Coach shortcut on heat / temperature steps (when the host wired it).
///
/// Pure, so the "which tools for this step" rules are unit-testable without a
/// SwiftUI host. Empty (no dock) on the Done card and on a step with no tools.
struct CookModeToolDockContent: Equatable {

    /// The current step's own timer duration, if its text names one.
    var stepTimerDuration: Duration?
    /// The index of the soonest-finishing timer running on a DIFFERENT step.
    var runningTimerStepIndex: Int?
    var showsHeatCoach: Bool

    var isEmpty: Bool {
        stepTimerDuration == nil && runningTimerStepIndex == nil && !showsHeatCoach
    }

    static let empty = CookModeToolDockContent(
        stepTimerDuration: nil,
        runningTimerStepIndex: nil,
        showsHeatCoach: false
    )

    /// - Parameter stepText: the current step's text, or nil on the Done card
    ///   (no dock there).
    static func resolve(
        currentStepIndex: Int,
        stepText: String?,
        heatCoachAvailable: Bool,
        timers: [Int: CookStepTimer],
        now: Date
    ) -> CookModeToolDockContent {
        guard let stepText else { return .empty }
        let otherRunning =
            timers
            .filter { $0.key != currentStepIndex && $0.value.isRunning }
            .min { lhs, rhs in
                (lhs.value.remaining(at: now), lhs.key) < (rhs.value.remaining(at: now), rhs.key)
            }?
            .key
        return CookModeToolDockContent(
            stepTimerDuration: StepTimerParser.firstDuration(in: stepText),
            runningTimerStepIndex: otherRunning,
            showsHeatCoach: heatCoachAvailable && CookModeView.stepIsHeatRelated(stepText)
        )
    }
}

/// DUT-1392 — "Step 4 Timer 03:12 · Go to Step", for a timer still running on a
/// step the cook has moved past. The whole row jumps back to that step.
struct CookModeRunningTimerRow: View {

    let stepIndex: Int
    let timer: CookStepTimer
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = timer.remaining(at: context.date)
                HStack(spacing: DODSpacing.sm) {
                    Image(systemName: "timer")
                        .font(.title3)
                        .foregroundStyle(DODColor.burntOrange)
                    Text("Step \(stepIndex + 1) Timer")
                        .dodFont(DODType.bodyEmphasized)
                        .foregroundStyle(DODColor.label)
                    Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                        .dodFont(DODType.bodyEmphasized)
                        .monospacedDigit()
                        .foregroundStyle(DODColor.labelSecondary)
                    Spacer(minLength: 0)
                    Text("Go to Step")
                        .dodFont(DODType.bodyEmphasized)
                        .foregroundStyle(DODColor.accent)
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DODColor.accent)
                }
                .cookModeDockCard()
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(stepIndex + 1) timer running")
        .accessibilityHint("go to step \(stepIndex + 1)")
        .accessibilityIdentifier("cook-mode-dock-running-timer")
    }
}

/// DUT-1392 — the Heat Coach shortcut as a dock row (was an inline link inside
/// the step text). Opens Heat Coach as a sheet over Cook Mode's cover.
struct CookModeHeatCoachRow: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DODSpacing.sm) {
                Image(systemName: "thermometer.medium")
                    .font(.title3)
                Text("Open Heat Coach")
                    .dodFont(DODType.bodyEmphasized)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(DODColor.burntOrange)
            .cookModeDockCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cook-mode-heat-coach")
    }
}

extension View {

    /// DUT-1392 — the dock's card look: elevated surface, hairline orange edge
    /// (matching the timer card), standard radius. Orange stays on the text and
    /// icons, never a full card fill.
    func cookModeDockCard() -> some View {
        self
            .padding(.horizontal, DODSpacing.md)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                    .fill(DODColor.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                    .strokeBorder(DODColor.burntOrange.opacity(0.25), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}
