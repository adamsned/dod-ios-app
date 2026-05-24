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
    let stepText: String
    /// Optional Live Activity sink. `CookModeView` supplies the owning
    /// view model so this timer can mirror its countdown to the Lock
    /// Screen (US-11). Standalone previews / SwiftUI hosts may omit it.
    weak var liveActivitySink: CookModeViewModel?

    @State private var remaining: Int
    @State private var isRunning: Bool = false
    @State private var didComplete: Bool = false
    /// Trigger token for `.sensoryFeedback` — we bump it to fire the haptic
    /// when the countdown hits zero. SwiftUI's modifier needs a value that
    /// changes (not a Bool, which would only fire once per `true` transition).
    @State private var completionTick: Int = 0

    init(duration: Duration, stepText: String = "", liveActivitySink: CookModeViewModel? = nil) {
        let seconds = Int(duration.components.seconds)
        self.totalSeconds = max(seconds, 0)
        self._remaining = State(initialValue: max(seconds, 0))
        self.stepText = stepText
        self.liveActivitySink = liveActivitySink
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
                togglePlay()
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

    private func togglePlay() {
        let goingToRun = !isRunning
        isRunning = goingToRun
        if goingToRun {
            // First Start (or Resume after Pause): make sure a Live
            // Activity exists and matches the current remaining time.
            // `start` is idempotent, so calling on resume is safe.
            liveActivitySink?.startTimerLiveActivity(
                stepText: stepText,
                totalSeconds: max(remaining, 0)
            )
            liveActivitySink?.updateTimerLiveActivity(
                remainingSeconds: remaining,
                stepText: stepText,
                isPaused: false
            )
        } else {
            liveActivitySink?.updateTimerLiveActivity(
                remainingSeconds: remaining,
                stepText: stepText,
                isPaused: true
            )
        }
    }

    private func tick() {
        guard isRunning, remaining > 0 else { return }
        remaining -= 1
        if remaining == 0 {
            isRunning = false
            didComplete = true
            completionTick &+= 1  // overflow-safe trigger bump
            liveActivitySink?.endTimerLiveActivity()
        } else {
            liveActivitySink?.updateTimerLiveActivity(
                remainingSeconds: remaining,
                stepText: stepText,
                isPaused: false
            )
        }
    }

    private func reset() {
        isRunning = false
        didComplete = false
        remaining = totalSeconds
        liveActivitySink?.endTimerLiveActivity()
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
