import SwiftUI

/// Pill-shaped status badge used to communicate the moderation lifecycle of
/// a user-submitted comment or rating. Reused by RecipeDetail (header
/// banner for in-flight submissions), `CommentComposer` (post-submit
/// feedback), and `CommentRow` (per-row "Awaiting approval" affordance).
///
/// Spec trace: US-13, US-14, US-15 (comments + ratings + guest identity).
public struct ModerationBadge: View {

    public enum Kind: Equatable, Sendable {
        case awaitingApproval
        case posted
        case failed
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }

    public var body: some View {
        HStack(spacing: DODSpacing.xxs) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            Text(label)
        }
        .dodFont(DODType.caption)
        .foregroundStyle(foreground)
        .padding(.horizontal, DODSpacing.xs)
        .padding(.vertical, DODSpacing.xxs)
        .background(Capsule().fill(background))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    private var label: String {
        switch kind {
        case .awaitingApproval: "Awaiting approval"
        case .posted: "Posted"
        case .failed: "Couldn't post"
        }
    }

    private var systemImage: String {
        switch kind {
        case .awaitingApproval: "clock"
        case .posted: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var background: Color {
        switch kind {
        case .awaitingApproval: DODColor.warmGold
        case .posted, .failed: DODColor.cream
        }
    }

    private var foreground: Color {
        switch kind {
        case .awaitingApproval: .white
        case .posted: .green
        case .failed: .red
        }
    }
}

#Preview("All kinds") {
    VStack(alignment: .leading, spacing: DODSpacing.sm) {
        ModerationBadge(kind: .awaitingApproval)
        ModerationBadge(kind: .posted)
        ModerationBadge(kind: .failed)
    }
    .padding(DODSpacing.md)
}
