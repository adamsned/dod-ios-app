import SwiftUI

/// Read-only star rating with a trailing "· N ratings" caption. Hosted by
/// `RecipeDetail` headers and `CommentRow` to show an aggregate or per-row
/// rating value.
///
/// When `count == 0` we deliberately return an `EmptyView` so the caller
/// can decide what to show in the empty state (e.g. "Be the first to rate
/// this recipe."). Embedding a fallback string here would force every host
/// to fight the layout.
///
/// Spec trace: US-13 (display aggregate rating + count).
public struct StarRatingDisplay: View {

    public let average: Double
    public let count: Int
    public let starSize: CGFloat
    /// DUT-646 — when `false`, the trailing "· N rating(s)" caption is
    /// suppressed and only the stars render. `CommentRow` passes `false`
    /// because a per-comment star line always represents exactly one rating,
    /// so a "· 1 rating" caption on every row is noise. Defaults to `true`
    /// to preserve the aggregate-header behavior (average + count).
    public let showsCount: Bool

    public init(average: Double, count: Int, starSize: CGFloat = 16, showsCount: Bool = true) {
        self.average = average
        self.count = count
        self.starSize = starSize
        self.showsCount = showsCount
    }

    public var body: some View {
        // `count` is an Int (rating count), not a Collection — empty_count
        // is misfiring; the integer equality check is the right primitive.
        if count == 0 {  // swiftlint:disable:this empty_count
            EmptyView()
        } else {
            HStack(spacing: DODSpacing.xxs) {
                stars
                if showsCount {
                    Text("· \(count) \(count == 1 ? "rating" : "ratings")")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var stars: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: symbol(for: index))
                    .font(.system(size: starSize))
                    .foregroundStyle(DODColor.warmGold)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Per-star bucket: filled if `average ≥ index + 0.75`, half if `≥ index + 0.25`,
    /// otherwise empty. The 0.25/0.75 thresholds round to the nearest half
    /// star, which matches how WPRM displays aggregate ratings on the web.
    private func symbol(for index: Int) -> String {
        let offset = average - Double(index)
        if offset >= 0.75 {
            return "star.fill"
        } else if offset >= 0.25 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }

    private var accessibilityLabel: String {
        let rounded = String(format: "%.1f", average)
        let suffix = count == 1 ? "rating" : "ratings"
        return "\(rounded) out of 5 stars, \(count) \(suffix)"
    }
}

/// Interactive 1–5 star input. Each tap sets the binding and fires a
/// selection haptic. Designed for the comment composer (large 36pt taps)
/// and for any future inline rating affordance.
///
/// `value == 0` is the "no rating" sentinel, displayed as five empty
/// outlines.
///
/// Spec trace: US-13 (rate a recipe), US-14 (submit comment + rating).
public struct StarRatingInput: View {

    @Binding public var value: Int
    public let starSize: CGFloat
    public let isSubmitting: Bool

    public init(value: Binding<Int>, starSize: CGFloat = 36, isSubmitting: Bool = false) {
        self._value = value
        self.starSize = starSize
        self.isSubmitting = isSubmitting
    }

    public var body: some View {
        HStack(spacing: DODSpacing.xs) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    value = star
                } label: {
                    Image(systemName: value >= star ? "star.fill" : "star")
                        .font(.system(size: starSize))
                        .foregroundStyle(DODColor.warmGold)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
        }
        .opacity(isSubmitting ? 0.5 : 1.0)
        // DUT-409: present as ONE adjustable control ("3 of 5 stars, adjustable")
        // rather than five separate buttons VoiceOver swipes through blind.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue(value == 0 ? "no rating selected" : "\(value) of 5 stars")
        .accessibilityAdjustableAction { direction in
            guard !isSubmitting else { return }
            switch direction {
            case .increment: value = min(value + 1, 5)
            // DUT-444: floor at 0, not 1 — from the "no rating" sentinel a
            // decrement used to compute max(-1, 1) = 1, so swiping DOWN set a
            // 1-star rating; and the floor of 1 meant VoiceOver could never
            // clear back to "no rating selected".
            case .decrement: value = max(value - 1, 0)
            default: break
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

#Preview("Display — 4.5 stars") {
    StarRatingDisplay(average: 4.5, count: 27)
        .padding(DODSpacing.md)
}

#Preview("Display — empty (renders nothing)") {
    VStack {
        Text("Above")
        StarRatingDisplay(average: 0, count: 0)
        Text("Below")
    }
    .padding(DODSpacing.md)
}

#Preview("Input — 0 selected") {
    StatefulStarPreview(initial: 0)
        .padding(DODSpacing.md)
}

#Preview("Input — 3 selected") {
    StatefulStarPreview(initial: 3)
        .padding(DODSpacing.md)
}

/// Bound preview helper. `@State` inside `#Preview` requires a real view.
private struct StatefulStarPreview: View {
    @State var value: Int
    init(initial: Int) { _value = State(initialValue: initial) }
    var body: some View {
        VStack(spacing: DODSpacing.md) {
            StarRatingInput(value: $value)
            Text("value = \(value)")
                .dodFont(DODType.caption)
        }
    }
}
