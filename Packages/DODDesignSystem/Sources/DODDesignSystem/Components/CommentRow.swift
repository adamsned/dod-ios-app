import SwiftUI

/// A single comment in the recipe detail comments list. Plain presentation:
/// the caller supplies pre-stripped body text (HTMLSanitizer lives in
/// DODSupport) and a pre-formatted relative date.
///
/// Spec trace: US-13 (read comments), US-14 (submit comments), US-15
/// (pending moderation visibility).
public struct CommentRow: View {

    public let authorName: String
    public let avatarURL: URL?
    public let relativeDate: String
    /// Pre-stripped comment text. Named `bodyText` (not `body`) because
    /// `View.body` already owns that identifier on the conforming view.
    public let bodyText: String
    public let ratingValue: Int?
    public let isPendingModeration: Bool

    public init(
        authorName: String,
        avatarURL: URL?,
        relativeDate: String,
        bodyText: String,
        ratingValue: Int? = nil,
        isPendingModeration: Bool = false
    ) {
        self.authorName = authorName
        self.avatarURL = avatarURL
        self.relativeDate = relativeDate
        self.bodyText = bodyText
        self.ratingValue = ratingValue
        self.isPendingModeration = isPendingModeration
    }

    public var body: some View {
        HStack(alignment: .top, spacing: DODSpacing.sm) {
            avatar

            VStack(alignment: .leading, spacing: DODSpacing.xs) {
                header
                Text(bodyText)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let ratingValue, ratingValue > 0 {
                    StarRatingDisplay(average: Double(ratingValue), count: 1, starSize: 12)
                }

                if isPendingModeration {
                    ModerationBadge(kind: .awaitingApproval)
                }
            }
        }
        .padding(.vertical, DODSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var avatar: some View {
        AsyncImage(url: avatarURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .empty, .failure:
                fallbackAvatar
            @unknown default:
                fallbackAvatar
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var fallbackAvatar: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(DODColor.labelSecondary)
            .frame(width: 40, height: 40)
    }

    private var header: some View {
        HStack(spacing: DODSpacing.xs) {
            Text(authorName)
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
            Text("·")
                .foregroundStyle(DODColor.labelSecondary)
            Text(relativeDate)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
            Spacer(minLength: 0)
        }
    }

    /// Collapsed VoiceOver label: identity + date + rating (if any) + body.
    private var accessibilityLabel: String {
        var parts: [String] = ["\(authorName), \(relativeDate)"]
        if let ratingValue, ratingValue > 0 {
            parts.append("rated \(ratingValue) star\(ratingValue == 1 ? "" : "s")")
        }
        parts.append(bodyText)
        if isPendingModeration {
            parts.append("Awaiting approval")
        }
        return parts.joined(separator: ". ")
    }
}

#Preview("With avatar + rating") {
    CommentRow(
        authorName: "Jamie L.",
        avatarURL: nil,
        relativeDate: "3 days ago",
        bodyText:
            "Made this last night and it was incredible. Subbed smoked paprika for the regular kind and it added a great depth.",
        ratingValue: 5
    )
    .padding(DODSpacing.md)
}

#Preview("Pending moderation") {
    CommentRow(
        authorName: "You",
        avatarURL: nil,
        relativeDate: "Just now",
        bodyText: "Question — can I sub butter for the oil?",
        ratingValue: 4,
        isPendingModeration: true
    )
    .padding(DODSpacing.md)
}
