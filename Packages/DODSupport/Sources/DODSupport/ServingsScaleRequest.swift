import Foundation

// DUT-1016 - bridge from the Siri "scale this to serve N" intent to the open
// recipe screen (same pattern as `dodSavedSetDidChange`).
extension Notification.Name {
    /// `object` is the recipe id (`Int`); `userInfo[ServingsScaleRequest.servingsKey]` is the requested count (`Int`).
    public static let dodServingsScaleRequested = Notification.Name("dod.servingsScaleRequested")
}

public enum ServingsScaleRequest {
    public static let servingsKey = "servings"

    /// Post the request for `recipeID`.
    public static func post(recipeID: Int, servings: Int) {
        NotificationCenter.default.post(
            name: .dodServingsScaleRequested,
            object: recipeID,
            userInfo: [servingsKey: servings]
        )
    }

    /// The requested count if `note` targets `recipeID`, else nil.
    public static func servings(from note: Notification, forRecipeID recipeID: Int) -> Int? {
        guard (note.object as? Int) == recipeID else { return nil }
        return note.userInfo?[servingsKey] as? Int
    }
}
