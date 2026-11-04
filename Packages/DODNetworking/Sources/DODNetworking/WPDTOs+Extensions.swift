import DODDomain
import DODSupport
import Foundation

// MARK: - Domain mapping

extension WPDTO.Post {
    /// Map to a `RecipeListItem` for list screens. Hero image URL is filled
    /// in later by the view-model (it requires a follow-up `/media/{id}` call
    /// or use of the featured media link if pre-resolved).
    ///
    /// `categoryIDs` is propagated from the wire payload (T-530 / CL-53 /
    /// REG-17) so the Search-tab category chip can filter fresh REST hits before
    /// a recipe-detail open hydrates `CachedRecipe.categoryIDs`. An omitted field
    /// (`categories == nil`) stays nil, not `[]` — the distinction lets the guard
    /// in `RecipeStore.cache(listItem:)` avoid clobbering a populated value.
    func toRecipeListItem(heroImage: URL?) -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: HTMLSanitizer.plainText(from: title.rendered),
            excerpt: HTMLSanitizer.plainText(from: WPDTO.strippingMoreLink(excerpt.rendered)),
            heroImage: heroImage,
            // DUT-311: `date_gmt` (UTC) drives `publishedAt`, not site-local `date`.
            publishedAt: WPDTO.parseWPDate(dateGMT ?? date),
            // DUT-1334: `modified_gmt` (UTC) when present, else nil → falls back.
            updatedAt: modifiedGMT.map { WPDTO.parseWPDate($0) },
            totalTimeDisplay: nil,
            canonicalURL: link,
            categoryIDs: categories
        )
    }
}

extension WPDTO.Category {
    func toDomain() -> DODDomain.Category {
        // DUT-426: sanitize like every other WP string — category names come
        // HTML-encoded ("Breads &amp; Rolls").
        DODDomain.Category(
            id: id,
            name: HTMLSanitizer.plainText(from: name),
            slug: slug,
            count: count,
            description: HTMLSanitizer.plainText(from: description ?? "")
        )
    }
}

extension WPDTO.Equipment {
    /// Map a wire-format equipment entry to the domain type, or `nil` when the
    /// entry is unusable (missing / blank name). Strips HTML from the name and
    /// parses `link` / `image_url` leniently — an empty or malformed URL just
    /// becomes `nil` rather than dropping the whole entry (AC-51.1).
    func toDomain() -> DODDomain.Equipment? {
        let cleanName = HTMLSanitizer.plainText(from: name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        return DODDomain.Equipment(
            name: cleanName,
            imageURL: WPDTO.parseOptionalURL(imageURL),
            link: WPDTO.parseOptionalURL(link)
        )
    }
}

extension WPDTO.RecipeCard {
    /// The recipe's equipment list, ready for the domain. Absent array → `[]`;
    /// entries with no usable name are skipped (AC-51.1). UI surfacing of this
    /// list ("Equipment & Tools" section) is a later slice.
    var equipmentList: [DODDomain.Equipment] {
        (equipment ?? []).compactMap { $0.toDomain() }
    }
}

extension WPDTO {
    /// Parse an optional URL leniently: nil / empty / whitespace / unparseable all collapse to `nil`.
    static func parseOptionalURL(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}

extension WPDTO.Comment {
    /// Map a wire-format comment to the public domain type. Strips HTML,
    /// normalizes parent=0 → nil, decodes unknown status strings to
    /// `.unknown` rather than throwing.
    func toDomain() -> RecipeComment {
        let normalizedParent: Int? = {
            guard let parent, parent > 0 else { return nil }
            return parent
        }()
        let mappedStatus: RecipeComment.Status = {
            guard let raw = status, let value = RecipeComment.Status(rawValue: raw) else {
                return .unknown
            }
            return value
        }()
        return RecipeComment(
            id: id,
            postID: post,
            parentID: normalizedParent,
            authorName: HTMLSanitizer.plainText(from: authorName ?? ""),
            // CL-139: WordPress's public `/wp/v2/comments` GET does NOT
            // include `author_email` in the response (privacy — email is
            // moderation-only data, only visible to admins via the
            // moderation queue or the authenticated `?context=edit` view).
            // The app uses the anonymous public endpoint, so every
            // FETCHED comment carries an empty `authorEmail`. The submit
            // path stamps `profile.email` locally on the just-posted
            // comment so own-comment photos render in-session.
            authorEmail: "",
            avatarURL: bestAvatarURL,
            dateGMT: WPDTO.parseWPDate(dateGMT),
            body: HTMLSanitizer.plainText(from: content?.rendered ?? ""),
            ratingValue: meta?.wprmCommentRating,
            status: mappedStatus
        )
    }
}
