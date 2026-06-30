import DODDesignSystem
import SwiftUI

/// Lock-screen card layout for a running Cook Mode timer (US-11).
///
/// Lives in the feature package — not in the widget extension — so the
/// snapshot test target (which can't import an app-extension binary) can
/// still pin the visual baseline. The widget extension wraps this view in
/// an `ActivityConfiguration` via ``CookActivityWidget``.
///
/// Layout:
/// - Recipe title on top in caption-emphasized type.
/// - Big monospaced countdown centered, tinted to ``DODColor/accent``.
/// - Step text below in body, truncated to one line.
/// - Tinted progress arc wrapped around the countdown numeral.
public struct CookActivityLockScreenView: View {

    public let recipeTitle: String
    public let stepText: String
    public let remainingSeconds: Int
    public let totalSeconds: Int
    public let isPaused: Bool
    /// DUT-218: when present + running, the countdown renders as a self-updating
    /// `Text(timerInterval:)` (ticks on the Lock Screen even when the app is
    /// backgrounded); `nil` (snapshots / paused) → the static `remainingSeconds`.
    public let endDate: Date?

    public init(
        recipeTitle: String,
        stepText: String,
        remainingSeconds: Int,
        totalSeconds: Int,
        isPaused: Bool,
        endDate: Date? = nil
    ) {
        self.recipeTitle = recipeTitle
        self.stepText = stepText
        self.remainingSeconds = remainingSeconds
        self.totalSeconds = totalSeconds
        self.isPaused = isPaused
        self.endDate = endDate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            HStack(alignment: .center, spacing: DODSpacing.xs) {
                Image(systemName: "frying.pan.fill")
                    .foregroundStyle(DODColor.burntOrange)
                Text(recipeTitle)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .lineLimit(1)
                Spacer()
                if isPaused {
                    Text("Paused")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                }
            }

            HStack(alignment: .center, spacing: DODSpacing.md) {
                CookActivityProgressArc(
                    progress: progress,
                    isPaused: isPaused,
                    countdown: countdownText
                )
                .frame(width: 88, height: 88)
                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    Text("Timer")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                    Text(stepText.isEmpty ? "Cook Mode" : stepText)
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.label)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(DODSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// DUT-218: self-updating `Text(timerInterval:)` while running (ticks even
    /// when backgrounded), falling back to the static snapshot when paused or
    /// when no `endDate` is supplied (snapshot tests).
    private var countdownText: Text {
        if let endDate, !isPaused, endDate > Date() {
            return Text(timerInterval: Date()...endDate, countsDown: true)
        }
        return Text(formattedCookActivityCountdown(remainingSeconds))
    }

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        let elapsed = Double(totalSeconds - remainingSeconds)
        return max(0, min(1, elapsed / Double(totalSeconds)))
    }
}

/// Compact countdown numeral with a tinted progress arc wrapped around it.
/// Reused by both the lock-screen card and the Dynamic Island expanded
/// layout so the visual treatment stays consistent across surfaces.
public struct CookActivityProgressArc: View {

    public let progress: Double
    public let isPaused: Bool
    /// DUT-218: a `Text` (not a `String`) so callers can pass a self-updating
    /// `Text(timerInterval:)` while running, or a static `Text` for snapshots.
    public let countdown: Text

    public init(progress: Double, isPaused: Bool, countdown: Text) {
        self.progress = progress
        self.isPaused = isPaused
        self.countdown = countdown
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(DODColor.surfaceElevated, lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(arcColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            countdown
                .dodFont(DODType.heading)
                .monospacedDigit()
                .foregroundStyle(DODColor.label)
        }
    }

    private var arcColor: Color {
        isPaused ? DODColor.labelSecondary : DODColor.accent
    }
}

/// Compact trailing region for the Dynamic Island: a tiny countdown.
public struct CookActivityCompactTrailingView: View {

    public let remainingSeconds: Int
    public let endDate: Date?

    public init(remainingSeconds: Int, endDate: Date? = nil) {
        self.remainingSeconds = remainingSeconds
        self.endDate = endDate
    }

    public var body: some View {
        countdownText
            .dodFont(DODType.bodyEmphasized)
            .monospacedDigit()
            .foregroundStyle(DODColor.accent)
    }

    /// DUT-218: self-updating while running (survives backgrounding), static
    /// snapshot when no `endDate` (snapshots) or already elapsed.
    private var countdownText: Text {
        if let endDate, endDate > Date() {
            return Text(timerInterval: Date()...endDate, countsDown: true)
        }
        return Text(formattedCookActivityCountdown(remainingSeconds))
    }
}

/// Compact leading region for the Dynamic Island: the cook-mode icon.
public struct CookActivityCompactLeadingView: View {

    public init() {}

    public var body: some View {
        Image(systemName: "frying.pan.fill")
            .foregroundStyle(DODColor.burntOrange)
    }
}

/// Internal helper — `mm:ss` countdown formatter shared across surfaces.
@inlinable
internal func formattedCookActivityCountdown(_ seconds: Int) -> String {
    let clamped = max(seconds, 0)
    let hours = clamped / 3600
    let minutes = (clamped % 3600) / 60
    let remainder = clamped % 60
    // DUT-404: match the running Text(timerInterval:) format for ≥1h timers so a
    // paused ≥60min countdown reads "1:15:00", not "75:00".
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, remainder)
    }
    return String(format: "%02d:%02d", minutes, remainder)
}
