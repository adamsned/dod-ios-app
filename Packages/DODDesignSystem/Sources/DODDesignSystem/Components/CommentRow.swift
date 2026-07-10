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
    /// US-44 / CL-139 / DUT-36 Phase d — optional caller-supplied avatar
    /// that replaces the AsyncImage / Gravatar path when non-nil. The
    /// caller is responsible for the same `40×40 Circle` frame the
    /// default avatar uses (a `ProfilePhotoView(diameter: 40)` matches
    /// out of the box). `nil` (the default) preserves the pre-Phase-d
    /// rendering for backward compatibility. AC-44.13.
    public let avatarOverride: AnyView?
    /// **Daddy Mode (Phase 1, cosmetic).** The commenter's Cook Rank, rendered
    /// as a small emoji + title line directly under the author name. `nil` (the
    /// default) renders NOTHING extra, so every existing call site + snapshot is
    /// byte-identical. Phase 1 populates this only for the current user's own
    /// comments; server-attached ranks for other users are a later phase.
    public let rank: (title: String, emoji: String)?
    /// **Daddy Mode (owner rank).** When `true`, the commenter's Cook Rank IS "The
    /// Dutch Oven Daddy": the rank line renders as the standout crown-capsule
    /// ``OwnerBadge`` (a SINGLE element, in place of the plain `rank` line — never
    /// a rank line PLUS a separate badge). `false` (the default) renders the plain
    /// `rank` line (or nothing when `rank` is nil), so existing calls + snapshots
    /// stay byte-identical.
    public let isOwnerRank: Bool

    public init(
        authorName: String,
        avatarURL: URL?,
        relativeDate: String,
        bodyText: String,
        ratingValue: Int? = nil,
        isPendingModeration: Bool = false,
        avatarOverride: AnyView? = nil,
        rank: (title: String, emoji: String)? = nil,
        isOwnerRank: Bool = false
    ) {
        self.authorName = authorName
        self.avatarURL = avatarURL
        self.relativeDate = relativeDate
        self.bodyText = bodyText
        self.ratingValue = ratingValue
        self.isPendingModeration = isPendingModeration
        self.avatarOverride = avatarOverride
        self.rank = rank
        self.isOwnerRank = isOwnerRank
    }

    public var body: some View {
        HStack(alignment: .top, spacing: DODSpacing.sm) {
            avatar

            VStack(alignment: .leading, spacing: DODSpacing.xs) {
                header
                ownerAndRankLine
                Text(bodyText)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let ratingValue, ratingValue > 0 {
                    // DUT-646 — `showsCount: false` suppresses the "· 1 rating"
                    // caption. A per-comment star line is always a single
                    // rating, so the caption is pure noise here.
                    StarRatingDisplay(
                        average: Double(ratingValue),
                        count: 1,
                        starSize: 12,
                        showsCount: false
                    )
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

    @ViewBuilder
    private var avatar: some View {
        if let avatarOverride {
            // CL-139 / Phase d: the caller supplied a custom avatar (e.g.
            // ``ProfilePhotoView`` for own-comment rows). Render in the
            // same 40×40 circular frame so the row layout is identical.
            avatarOverride
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .accessibilityHidden(true)
        } else {
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
    }

    private var fallbackAvatar: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(DODColor.labelSecondary)
            .frame(width: 40, height: 40)
    }

    /// **Daddy Mode (owner rank).** The Cook Rank line shown under the author name.
    /// The owner's rank IS "The Dutch Oven Daddy", rendered as the standout
    /// crown-capsule ``OwnerBadge`` (a single element — the rank carries the owner
    /// identity, there is no separate badge). Everyone else gets the plain
    /// emoji + title rank line. Renders nothing (and takes no vertical space —
    /// SwiftUI collapses an empty `@ViewBuilder`) when this is a non-owner row with
    /// no `rank`, so the default row is byte-identical.
    @ViewBuilder
    private var ownerAndRankLine: some View {
        if isOwnerRank {
            HStack(spacing: DODSpacing.xs) {
                OwnerBadge()
                Spacer(minLength: 0)
            }
        } else if let rank {
            HStack(spacing: DODSpacing.xs) {
                Text("\(rank.emoji) \(rank.title)")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                Spacer(minLength: 0)
            }
        }
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
        // Daddy Mode (owner rank) — additive: absent by default. The owner's rank
        // IS "The Dutch Oven Daddy", so announce it in place of a plain rank.
        if isOwnerRank {
            parts.append("The Dutch Oven Daddy, app owner")
        } else if let rank {
            parts.append("\(rank.title) rank")
        }
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

#Preview("Owner rank") {
    // Daddy Mode (owner rank): the rank line IS the crown badge — a single element.
    CommentRow(
        authorName: "Ned A.",
        avatarURL: nil,
        relativeDate: "2 hours ago",
        bodyText: "This is the one. Get the coals white-hot and don't peek.",
        ratingValue: 5,
        rank: ("The Dutch Oven Daddy", "👑"),
        isOwnerRank: true
    )
    .padding(DODSpacing.md)
}
