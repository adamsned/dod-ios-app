import Foundation

extension Notification.Name {

    /// DUT-1388 — posted after a save or unsave that happened OUTSIDE the
    /// screen showing it (a Siri / Shortcuts "Save this recipe"), so an open
    /// recipe screen can re-read its bookmark state instead of showing a stale
    /// one. `object` is the recipe id (`Int`).
    public static let dodSavedSetDidChange = Notification.Name("dod.savedSetDidChange")
}
