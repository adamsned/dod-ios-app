import SwiftUI

/// A reusable, data-driven "step walkthrough" control, styled after Cook Mode's
/// step surface (the large `displayMedium` step text, the slim burnt-orange
/// progress bar with a "Step X of Y" caption, and a Prev / Next transport row).
///
/// Unlike Cook Mode's `CookModeView`, this component is **not** tied to any view
/// model: it takes an ordered `[String]` of step texts and a `Binding<Int>` for
/// the active index, so both First Cookout (walking a recipe/coaching flow) and,
/// later, Cook Mode can adopt it. It owns no timers, audio, or idle-timer
/// behaviour — core step navigation only.
///
/// ## Driving the index
/// The active step is driven entirely through the `currentIndex` binding. Tapping
/// **Prev** / **Next** (or swiping horizontally) mutates the binding, clamped to
/// `0..<steps.count`; the host observes the change. **Prev** is disabled (and
/// hidden from VoiceOver) on the first step, **Next** on the last — the host can
/// watch for `currentIndex == steps.count - 1` to reveal its own "Done" CTA.
///
/// ## Accessibility
/// Each transport button carries an explicit label ("Previous step" / "Next
/// step") and a 44pt minimum tap target. At the ends the disabled button is
/// `accessibilityHidden` so VoiceOver skips a dead control. The step text is
/// exposed as its own element, and the progress bar reads "Step X of Y".
///
/// Rendering is theme-aware via design-system tokens (light/dark both handled).
public struct StepWalkthroughView: View {

    private let steps: [String]
    @Binding private var currentIndex: Int
    private let allowsSwipe: Bool

    /// - Parameters:
    ///   - steps: Ordered step texts. An empty array renders an empty-state
    ///     placeholder rather than crashing.
    ///   - currentIndex: The active 0-based step index. Mutated by the transport
    ///     controls (and swipe, when enabled); always clamped into range.
    ///   - allowsSwipe: When `true` (the default), a horizontal drag advances /
    ///     retreats a step, mirroring Cook Mode's paged feel. Set `false` for
    ///     hosts that own the gesture themselves.
    public init(
        steps: [String],
        currentIndex: Binding<Int>,
        allowsSwipe: Bool = true
    ) {
        self.steps = steps
        self._currentIndex = currentIndex
        self.allowsSwipe = allowsSwipe
    }

    private var progress: StepProgress {
        StepProgress(currentIndex: currentIndex, count: steps.count)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.lg) {
            stepText
            Spacer(minLength: 0)
            StepProgressBar(progress: progress)
            transportRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DODSpacing.md)
        .padding(.vertical, DODSpacing.lg)
        .contentShape(Rectangle())
        .modifier(SwipeToAdvance(enabled: allowsSwipe, onPrev: goToPrevious, onNext: goToNext))
    }

    // MARK: - Step text (matches Cook Mode's `displayMedium` step body)

    @ViewBuilder
    private var stepText: some View {
        if let text = currentStepText {
            Text(text)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
                .lineSpacing(DODSpacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(progress.caption). \(text)")
        } else {
            Text("No steps to show.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var currentStepText: String? {
        guard steps.indices.contains(progress.activeIndex) else { return nil }
        return steps[progress.activeIndex]
    }

    // MARK: - Transport row (Prev / Next, styled after CookModePlayerControls)

    private var transportRow: some View {
        HStack(spacing: DODSpacing.md) {
            transportButton(
                title: "Prev",
                symbol: "arrow.backward",
                label: "Previous step",
                isDisabled: progress.isFirst,
                action: goToPrevious
            )
            .accessibilityIdentifier("step-walkthrough-previous")

            transportButton(
                title: "Next",
                symbol: "arrow.forward",
                label: "Next step",
                symbolLeading: false,
                isDisabled: progress.isLast,
                action: goToNext
            )
            .accessibilityIdentifier("step-walkthrough-next")
        }
        .frame(maxWidth: .infinity)
    }

    /// A burnt-orange accent **pill** transport button (constitution's pill tier
    /// for buttons), cream label, with a 44pt minimum tap target. Disabled +
    /// hidden from VoiceOver at the ends of the walkthrough.
    private func transportButton(
        title: String,
        symbol: String,
        label: String,
        symbolLeading: Bool = true,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DODSpacing.xs) {
                if symbolLeading { Image(systemName: symbol) }
                Text(title)
                if !symbolLeading { Image(systemName: symbol) }
            }
            .dodFont(DODType.bodyEmphasized)
            .foregroundStyle(DODColor.cream)
            .frame(maxWidth: .infinity)
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, DODSpacing.md)
            .background(Capsule().fill(DODColor.accent))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.35 : 1)
        .disabled(isDisabled)
        .accessibilityLabel(label)
        .accessibilityHidden(isDisabled)
    }

    // MARK: - Index mutation (clamped)

    private func goToPrevious() {
        guard !progress.isFirst else { return }
        currentIndex = progress.activeIndex - 1
    }

    private func goToNext() {
        guard !progress.isLast else { return }
        currentIndex = progress.activeIndex + 1
    }
}

/// The slim progress bar + "Step X of Y" caption, matching
/// `CookModeStepIndicator`'s look: a `surfaceDivider` track carrying a
/// `burntOrange` fill sized to ``StepProgress/fraction``.
private struct StepProgressBar: View {

    let progress: StepProgress

    var body: some View {
        VStack(spacing: DODSpacing.xs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DODColor.surfaceDivider)
                    Capsule()
                        .fill(DODColor.burntOrange)
                        .frame(width: max(6, geo.size.width * progress.fraction))
                }
            }
            .frame(height: 6)

            Text(progress.caption)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: 280)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progress.accessibilityLabel)
    }
}

/// A horizontal swipe-to-advance gesture, factored into its own modifier so the
/// main body stays declarative. Left drag → next, right drag → previous. A no-op
/// when `enabled` is `false`.
private struct SwipeToAdvance: ViewModifier {

    let enabled: Bool
    let onPrev: () -> Void
    let onNext: () -> Void

    /// Horizontal travel (points) required before a drag counts as a step swipe.
    private let threshold: CGFloat = 44

    func body(content: Content) -> some View {
        if enabled {
            content.gesture(
                DragGesture(minimumDistance: threshold)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        if value.translation.width < -threshold {
                            onNext()
                        } else if value.translation.width > threshold {
                            onPrev()
                        }
                    }
            )
        } else {
            content
        }
    }
}

#Preview("Step walkthrough — middle step") {
    StatefulWalkthroughPreview(
        steps: [
            "Light a full chimney of charcoal and let the coals ash over.",
            "Arrange 17 coals underneath and 8 on the lid for a 350°F oven.",
            "Rest the brisket 20 minutes before slicing against the grain.",
        ],
        initialIndex: 1
    )
}

#Preview("Step walkthrough — first step (Prev disabled)") {
    StatefulWalkthroughPreview(
        steps: [
            "Light a full chimney of charcoal and let the coals ash over.",
            "Arrange 17 coals underneath and 8 on the lid for a 350°F oven.",
        ],
        initialIndex: 0
    )
}

/// Bound preview host — `@State` inside `#Preview` needs a concrete view.
private struct StatefulWalkthroughPreview: View {
    let steps: [String]
    @State private var index: Int
    init(steps: [String], initialIndex: Int) {
        self.steps = steps
        _index = State(initialValue: initialIndex)
    }
    var body: some View {
        StepWalkthroughView(steps: steps, currentIndex: $index)
    }
}
