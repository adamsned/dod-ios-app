import Foundation

/// One "I made this" entry in the private cook journal (US-48 / DUT-104).
///
/// A value type holding only primitives so it stays decoupled from Domain +
/// Persistence: the SwiftData layer (a later slice) maps to/from this, and the
/// pure ``CookLogStats`` calculator works over `[CookLogEntry]` without a store.
/// Everything here is private to the user — it is never sent to the blog or
/// analytics (contrast the public comments/ratings).
public struct CookLogEntry: Identifiable, Sendable, Equatable {

    public let id: UUID
    /// The WP post id of the recipe that was cooked.
    public let recipeID: Int
    /// Snapshot of the recipe title at log time (so history reads correctly even
    /// if the recipe is later renamed or unpublished).
    public let recipeTitle: String
    /// When it was cooked.
    public let cookedAt: Date
    /// Optional private note ("used less salt next time").
    public let note: String?
    /// Optional private 1–5 rating the user gives their own result. Distinct
    /// from the public star rating posted to the blog.
    public let personalRating: Int?
    /// DUT-975 — optional private 1–5 "how did that feel?" confidence read
    /// (1 = felt hard, 5 = felt easy). Distinct from `personalRating` (result quality).
    public let confidence: Int?
    /// Optional local identifier for an attached photo (resolved by the photo
    /// store in a later slice). Kept as a string so this type has no UIKit dep.
    public let photoLocalID: String?
    /// DUT-994: why this was cooked. Defaults to `.everyday` so existing call sites compile unchanged.
    public let occasion: CookOccasion
    /// DUT-994: optional private first name or label of who it was cooked for (comfort cooks).
    public let recipient: String?

    public init(
        id: UUID,
        recipeID: Int,
        recipeTitle: String,
        cookedAt: Date,
        note: String? = nil,
        personalRating: Int? = nil,
        photoLocalID: String? = nil,
        confidence: Int? = nil,
        occasion: CookOccasion = .everyday,
        recipient: String? = nil
    ) {
        self.id = id
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.cookedAt = cookedAt
        self.note = note
        // Clamp a personal rating into 1...5 (or nil) so downstream UI can trust it.
        self.personalRating = personalRating.map { min(5, max(1, $0)) }
        self.photoLocalID = photoLocalID
        self.confidence = confidence.map { min(5, max(1, $0)) }
        self.occasion = occasion
        let trimmed = recipient?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.recipient = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }
}
