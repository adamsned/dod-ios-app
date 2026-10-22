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
    /// DUT-490 / DUT-491: the DUT-354 buzzer linger — a done (not paused) timer.
    /// When set, the status pill reads "Done" instead of "Paused".
    public let isCompleted: Bool

    public init(
        recipeTitle: String,
        stepText: String,
        remainingSeconds: Int,
        totalSeconds: Int,
        isPaused: Bool,
        endDate: Date? = nil,
        isCompleted: Bool = false
    ) {
        self.recipeTitle = recipeTitle
        self.stepText = stepText
        self.remainingSeconds = remainingSeconds
        self.totalSeconds = totalSeconds
        self.isPaused = isPaused
        self.endDate = endDate
        self.isCompleted = isCompleted
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            HStack(alignment: .center, spacing: DODSpacing.xs) {
                Image(systemName: "frying.pan.fill")
                    .foregroundStyle(DODColor.burntOrange)
                    // DUT-694: decorative here — VO already reads the title next to
                    // it, so "frying pan, <title>" is noise. Hide only this
                    // title-row glyph; the compact/minimal pan stays (sole element).
                    .accessibilityHidden(true)
                Text(recipeTitle)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .lineLimit(1)
                    // Dynamic Type: `recipeTitle` is the same unbounded,
                    // WPRM-authored recipe name DUT-527 found truncating to
                    // "Veget…" elsewhere at large accessibility text sizes —
                    // and this view renders on both the Lock Screen and the
                    // Dynamic Island expanded region, where every OTHER
                    // single-line text below (the countdown numeral, the
                    // compact-trailing countdown) already shrinks via
                    // `.minimumScaleFactor` (DUT-694, DUT-662) instead of
                    // clipping. The title was the one line in this file that
                    // hadn't gotten that same treatment.
                    .minimumScaleFactor(0.7)
                Spacer()
                if isCompleted {
                    // DUT-491: the DUT-354 buzzer moment is "Done", not "Paused".
                    Text("Done")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.accent)
                } else if isPaused {
                    Text("Paused")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                }
            }

            HStack(alignment: .center, spacing: DODSpacing.md) {
                // DUT-267: while RUNNING with a wall-clock deadline, the ring's
                // fill would freeze the moment the app backgrounds (it's a pure
                // function of the last PUSHED remainingSeconds, while the
                // numeral self-ticks) — so the running state drives progress
                // with the system's self-updating timer bar below instead, and
                // the ring renders the numeral only. Paused / snapshot states
                // keep the full static arc (their numbers can't drift).
                CookActivityProgressArc(
                    progress: progress,
                    isPaused: isPaused,
                    countdown: countdownText,
                    showsRing: !isSelfTicking,
                    isCompleted: isCompleted
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
                    if let endDate, isSelfTicking {
                        // Self-updating on the Lock Screen even while the app
                        // is backgrounded — same primitive as the numeral.
                        let start = endDate.addingTimeInterval(-TimeInterval(totalSeconds))
                        ProgressView(
                            timerInterval: start...endDate,
                            countsDown: false,
                            label: { EmptyView() },
                            currentValueLabel: { EmptyView() }
                        )
                        .progressViewStyle(.linear)
                        .tint(DODColor.accent)
                        // DUT-694: the self-ticking bar echoes the numeral as an
                        // unlabeled a11y element — decorative, so hide it from VO.
                        .accessibilityHidden(true)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(DODSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// DUT-267 — true when the countdown renders as a self-updating
    /// `Text(timerInterval:)` (running with a future deadline); the progress
    /// treatment must self-update the same way or it visibly desyncs.
    private var isSelfTicking: Bool {
        guard let endDate, !isPaused else { return false }
        return endDate > Date()
    }

    /// DUT-218: self-updating `Text(timerInterval:)` while running (ticks even
    /// when backgrounded), falling back to the static snapshot when paused or
    /// when no `endDate` is supplied (snapshot tests).
    private var countdownText: Text {
        // DUT-720: sample the clock once so the guard and the range use the same
        // instant — avoids a fatalError if the wall clock crosses `endDate`
        // between two separate `Date()` samplings.
        let now = Date()
        if !isPaused, let endDate, now < endDate {
            return Text(timerInterval: now...endDate, countsDown: true)
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
    /// DUT-267: false while the numeral self-ticks — the trim-based ring can't
    /// self-update, so showing it then means a visibly frozen fill against a
    /// live numeral. The base circle stays as the numeral's frame.
    public let showsRing: Bool
    /// DUT-491: a completed (buzzer) timer is technically `isPaused == true`, but
    /// its full ring should read as "done" (accent) rather than the muted paused
    /// treatment.
    public let isCompleted: Bool

    public init(
        progress: Double,
        isPaused: Bool,
        countdown: Text,
        showsRing: Bool = true,
        isCompleted: Bool = false
    ) {
        self.progress = progress
        self.isPaused = isPaused
        self.countdown = countdown
        self.showsRing = showsRing
        self.isCompleted = isCompleted
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(DODColor.surfaceElevated, lineWidth: 6)
            if showsRing {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(arcColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            countdown
                .dodFont(DODType.heading)
                .monospacedDigit()
                // DUT-694: an `H:MM:SS` countdown ("1:15:00") overflows the fixed
                // 88pt ring at large Dynamic Type — shrink to fit one line.
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(DODColor.label)
                // DUT-694 a11y: without a label VoiceOver reads a bare ticking
                // "1:15:00" with no meaning. Labeling a `Text(timerInterval:)`
                // keeps it announcing its live value alongside the context.
                .accessibilityLabel(countdownAccessibilityLabel)
        }
    }

    /// DUT-694 a11y: give the bare countdown numeral spoken context, reflecting
    /// the done/paused state the numeral's tint already conveys visually.
    private var countdownAccessibilityLabel: String {
        if isCompleted { return "Timer complete" }
        if isPaused { return "Time remaining, paused" }
        return "Time remaining"
    }

    private var arcColor: Color {
        // DUT-491: a completed timer keeps the accent fill (done, not muted).
        if isCompleted { return DODColor.accent }
        return isPaused ? DODColor.labelSecondary : DODColor.accent
    }
}

/// Compact trailing region for the Dynamic Island: a tiny countdown.
public struct CookActivityCompactTrailingView: View {

    public let remainingSeconds: Int
    public let endDate: Date?
    /// DUT-662: a paused timer must not self-tick and must read muted, matching
    /// the card — a bright accent countdown that keeps counting contradicts a
    /// paused/done card.
    public let isPaused: Bool
    /// DUT-662: mirrors ``CookActivityProgressArc.arcColor`` — a completed
    /// (buzzer) timer keeps the accent fill even though it is technically paused.
    public let isCompleted: Bool

    public init(
        remainingSeconds: Int,
        endDate: Date? = nil,
        isPaused: Bool = false,
        isCompleted: Bool = false
    ) {
        self.remainingSeconds = remainingSeconds
        self.endDate = endDate
        self.isPaused = isPaused
        self.isCompleted = isCompleted
    }

    public var body: some View {
        // DUT-662: a ≥1h `H:MM:SS` countdown (7 chars) has no width budget in the
        // Dynamic Island trailing slot and clips — shrink to fit on one line.
        countdownText
            .dodFont(DODType.bodyEmphasized)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(countdownColor)
            // DUT-694 a11y: this is the always-on `minimal` pill (the sole glimpse
            // of a running timer) as well as compact-trailing / expanded trailing.
            // Without a label VoiceOver reads a bare ticking "1:15:00"; labeling a
            // `Text(timerInterval:)` keeps its live value announced with context.
            .accessibilityLabel(countdownAccessibilityLabel)
    }

    /// DUT-694 a11y: spoken context for the bare countdown numeral, mirroring the
    /// done/paused state the numeral's tint conveys visually.
    private var countdownAccessibilityLabel: String {
        if isCompleted { return "Timer complete" }
        if isPaused { return "Time remaining, paused" }
        return "Time remaining"
    }

    /// DUT-218: self-updating while running (survives backgrounding), static
    /// snapshot when no `endDate` (snapshots), already elapsed, or paused — a
    /// paused timer must freeze rather than keep ticking (DUT-662).
    private var countdownText: Text {
        // DUT-720: sample the clock once so the guard and the range share the
        // same instant, preventing a fatalError at the expiry boundary.
        let now = Date()
        if let endDate, !isPaused, now < endDate {
            return Text(timerInterval: now...endDate, countsDown: true)
        }
        return Text(formattedCookActivityCountdown(remainingSeconds))
    }

    /// DUT-662: mirror ``CookActivityProgressArc.arcColor`` so the numeral's tint
    /// agrees with the card — muted when paused, accent when running or completed.
    private var countdownColor: Color {
        if isCompleted { return DODColor.accent }
        return isPaused ? DODColor.labelSecondary : DODColor.accent
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
