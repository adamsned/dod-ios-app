import DODSupport
import Foundation

/// Input for the on-device Hero Moment caption (DUT-1008). Plain values so
/// callers never touch FoundationModels. Everything stays on-device.
public struct MomentCaptionRequest: Sendable, Equatable {
    public let recipeTitle: String
    public let note: String?
    public let personalRating: Int?
    /// Optional JPEG/PNG bytes of the cook-log photo (resolved by the caller from `photoLocalID`).
    public let imageData: Data?

    public init(recipeTitle: String, note: String? = nil, personalRating: Int? = nil, imageData: Data? = nil) {
        self.recipeTitle = recipeTitle
        self.note = note
        self.personalRating = personalRating
        self.imageData = imageData
    }

    public init(entry: CookLogEntry, imageData: Data? = nil) {
        self.init(
            recipeTitle: entry.recipeTitle,
            note: entry.note,
            personalRating: entry.personalRating,
            imageData: imageData
        )
    }

    /// True when there is nothing for the model to react to beyond the title.
    public var hasMoment: Bool {
        let hasNote = !(note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return hasNote || imageData != nil
    }
}
