import DODDesignSystem
import SwiftUI

/// One row in the "Ask Dutch Oven Daddy" conversation: a right-aligned user
/// bubble or a left-aligned assistant answer card. Split out of
/// `CookingHelperSheet.swift` to keep that file under the SwiftLint 400-line cap.
struct CookingHelperTurnView: View {

    let turn: CookingHelperViewModel.Turn

    var body: some View {
        switch turn.role {
        case .user:
            userBubble
        case .assistant:
            assistantCard
        }
    }

    // MARK: - User

    private var userBubble: some View {
        HStack {
            Spacer(minLength: DODSpacing.xl)
            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                if turn.hasImage {
                    Label("Photo attached", systemImage: "photo")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelOnAccent.opacity(0.9))
                }
                if !turn.text.isEmpty {
                    Text(turn.text)
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.labelOnAccent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, DODSpacing.md)
            .padding(.vertical, DODSpacing.sm)
            .background(DODColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You asked: \(turn.hasImage ? "with a photo. " : "")\(turn.text)")
    }

    // MARK: - Assistant

    private var assistantCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: DODSpacing.xs) {
                Label {
                    Text("Dutch Oven Daddy")
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.accent)
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(DODColor.accent)
                }
                Text(turn.text)
                    .dodFont(DODType.body)
                    .foregroundStyle(turn.isEmptyResult ? DODColor.labelSecondary : DODColor.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DODSpacing.md)
            .background(DODColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
            Spacer(minLength: DODSpacing.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dutch Oven Daddy answered: \(turn.text)")
    }
}

/// The "Thinking" placeholder row shown while an answer is in flight.
struct CookingHelperThinkingView: View {
    var body: some View {
        HStack(spacing: DODSpacing.sm) {
            ProgressView()
                .tint(DODColor.accent)
            Text("Thinking…")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
            Spacer(minLength: 0)
        }
        .padding(DODSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Thinking")
    }
}
