import Combine
import DODDesignSystem
import SwiftUI

/// Compact inline countdown timer offered by Cook Mode when a step's text
/// contains a parseable duration (see `StepTimerParser`). One-shot, visual
/// only — no notification or sound (v1 scope).
///
/// Lifecycle:
/// - The user has to tap Start before the clock begins running. We don't
///   auto-start; tapping a parsed duration is the explicit opt-in.
/// - Pause freezes the countdown without resetting; tapping Start resumes.
/// - Reset returns to the original duration and stops.
/// - When the clock reaches 00:00, the time turns ``DODColor.accent`` and
///   `.sensoryFeedback(.success, trigger: completed)` fires once.
struct CookTimer: View {

    let totalSeconds: Int

    @State private var remaining: Int
    @State private var isRunning: Bool = false
    @State private var didComplete: Bool = false
    /// Trigger token for `.sensoryFeedback` — we bump it to fire the haptic
    /// when the countdown hits zero. SwiftUI's modifier needs a value that
    /// changes (not a Bool, which would only fire once per `true` transition).
    @State private var completionTick: Int = 0

    init(duration: Duration) {
        let seconds = Int(duration.components.seconds)
        self.totalSeconds = max(seconds, 0)
        self._remaining = State(initialValue: max(seconds, 0))
    }

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: DODSpacing.sm) {
            Image(systemName: "timer")
                .foregroundStyle(displayColor)
                .font(.title3)
                .accessibilityHidden(true)
            Text(formatted)
                .dodFont(DODType.displayMedium)
                .monospacedDigit()
                .foregroundStyle(displayColor)
                .accessibilityLabel(accessibilityTimeLabel)
                .frame(minWidth: 88, alignment: .leading)
            Spacer(minLength: 0)
            controls
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        .onReceive(ticker) { _ in tick() }
        .sensoryFeedback(.success, trigger: completionTick)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: DODSpacing.xs) {
            Button(isRunning ? "Pause" : (didComplete ? "Done" : "Start")) {
                if didComplete { return }
                isRunning.toggle()
            }
            .buttonStyle(.borderedProminent)
            .tint(DODColor.accent)
            .disabled(didComplete)
            .accessibilityLabel(isRunning ? "Pause timer" : "Start timer")

            Button("Reset") { reset() }
                .buttonStyle(.bordered)
                .tint(DODColor.labelSecondary)
                .accessibilityLabel("Reset timer")
        }
    }

    // MARK: - State transitions

    private func tick() {
        guard isRunning, remaining > 0 else { return }
        remaining -= 1
        if remaining == 0 {
            isRunning = false
            didComplete = true
            completionTick &+= 1  // overflow-safe trigger bump
        }
    }

    private func reset() {
        isRunning = false
        didComplete = false
        remaining = totalSeconds
    }

    // MARK: - Display helpers

    private var displayColor: Color {
        didComplete ? DODColor.accent : DODColor.label
    }

    private var formatted: String {
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var accessibilityTimeLabel: String {
        let minutes = remaining / 60
        let seconds = remaining % 60
        if minutes > 0 && seconds > 0 {
            return "\(minutes) minutes \(seconds) seconds remaining"
        }
        if minutes > 0 {
            return "\(minutes) minutes remaining"
        }
        return "\(seconds) seconds remaining"
    }
}
