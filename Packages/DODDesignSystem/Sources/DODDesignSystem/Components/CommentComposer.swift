import SwiftUI

/// Sheet-style composer for submitting a comment + optional star rating.
/// The caller is responsible for wrapping this in a `.sheet(...)`; we render
/// only the sheet contents (title + form + buttons) so the host controls
/// presentation detents, dismissal, and keyboard handling.
///
/// Submit is enabled iff at least one of comment/rating is provided AND we
/// are not already submitting. Empty + unrated is treated as "nothing to
/// post" — better to block submit than silently no-op (US-14 AC: must
/// submit at least one of comment or rating).
///
/// Spec trace: US-13 (rate), US-14 (comment).
public struct CommentComposer: View {

    @Binding public var text: String
    @Binding public var rating: Int
    public let maxCharacters: Int
    public let isSubmitting: Bool
    public let onSubmit: @MainActor () -> Void
    public let onCancel: @MainActor () -> Void

    public init(
        text: Binding<String>,
        rating: Binding<Int>,
        maxCharacters: Int = 1000,
        isSubmitting: Bool,
        onSubmit: @MainActor @escaping () -> Void,
        onCancel: @MainActor @escaping () -> Void
    ) {
        self._text = text
        self._rating = rating
        self.maxCharacters = maxCharacters
        self.isSubmitting = isSubmitting
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.lg) {
            header

            ratingRow

            editor

            counter

            Spacer(minLength: 0)

            actions
        }
        .padding(DODSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DODColor.surface)
    }

    private var header: some View {
        Text("Write a Comment")
            .dodFont(DODType.displayMedium)
            .foregroundStyle(DODColor.label)
            .accessibilityAddTraits(.isHeader)
    }

    private var ratingRow: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("Rate (Optional)")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            StarRatingInput(value: $rating, starSize: 32, isSubmitting: isSubmitting)
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            // Background border to give the editor visual containment.
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .stroke(DODColor.labelSecondary.opacity(0.25), lineWidth: 1)

            TextEditor(text: $text)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .scrollContentBackground(.hidden)
                .padding(DODSpacing.xs)
                .frame(minHeight: 140)
                .disabled(isSubmitting)
                .accessibilityLabel("Comment body")

            if text.isEmpty {
                Text("Share your tips, substitutions, or thoughts.")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary.opacity(0.7))
                    .padding(.horizontal, DODSpacing.sm)
                    .padding(.vertical, DODSpacing.sm + 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private var counter: some View {
        HStack {
            Spacer()
            Text("\(text.count) / \(maxCharacters)")
                .dodFont(DODType.caption)
                .foregroundStyle(counterColor)
                .monospacedDigit()
                .accessibilityLabel("\(text.count) of \(maxCharacters) characters used")
        }
    }

    private var actions: some View {
        // Submit (primary) at leading, Cancel (role: .cancel) at trailing —
        // a deliberate visual swap from the iPhone-stock HIG default per
        // US-26 / AC-26.3 / CL-41. The cancel role is preserved on the
        // Cancel button so VoiceOver + the system back-gesture still
        // honor it as the cancel affordance; the swap is purely visual.
        HStack(spacing: DODSpacing.md) {
            Button(action: onSubmit) {
                Text(isSubmitting ? "Submitting..." : "Submit")
                    .dodFont(DODType.bodyEmphasized)
                    .padding(.horizontal, DODSpacing.lg)
                    .padding(.vertical, DODSpacing.sm)
            }
            .dodProminentButton()
            .tint(DODColor.accent)
            .disabled(!canSubmit)

            Spacer()

            Button(role: .cancel, action: onCancel) {
                Text("Cancel")
                    .dodFont(DODType.bodyEmphasized)
                    .padding(.horizontal, DODSpacing.lg)
                    .padding(.vertical, DODSpacing.sm)
            }
            .dodBorderedButton()
            .disabled(isSubmitting)
        }
    }

    /// Threshold at which the counter flips to red — 95% of max, per
    /// task spec ("turns red at 95%").
    private var counterColor: Color {
        let limit = Double(maxCharacters) * 0.95
        return Double(text.count) >= limit ? .red : DODColor.labelSecondary
    }

    /// Either the trimmed body OR a non-zero rating qualifies as a real
    /// submission. Disabled while in-flight to prevent double-tap.
    private var canSubmit: Bool {
        guard !isSubmitting else { return false }
        let hasComment = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasRating = rating > 0
        return hasComment || hasRating
    }
}

#Preview("Empty state") {
    StatefulComposerPreview(text: "", rating: 0, isSubmitting: false)
}

#Preview("Filled state") {
    StatefulComposerPreview(
        text:
            "Made this for Sunday dinner and the whole family went back for seconds. Used cast iron instead of the suggested skillet and it was perfect.",
        rating: 5,
        isSubmitting: false
    )
}

#Preview("Submitting") {
    StatefulComposerPreview(
        text: "Loved it!",
        rating: 4,
        isSubmitting: true
    )
}

private struct StatefulComposerPreview: View {
    @State var text: String
    @State var rating: Int
    let isSubmitting: Bool

    init(text: String, rating: Int, isSubmitting: Bool) {
        _text = State(initialValue: text)
        _rating = State(initialValue: rating)
        self.isSubmitting = isSubmitting
    }

    var body: some View {
        CommentComposer(
            text: $text,
            rating: $rating,
            isSubmitting: isSubmitting,
            onSubmit: {},
            onCancel: {}
        )
    }
}
