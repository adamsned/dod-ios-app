import Foundation
import Observation

/// DUT-160 — assembles the Privacy Dashboard's three location buckets from
/// live, on-device state. Reads counts through the same `SettingsDependencies`
/// seam the Profile-stats surface uses (saved recipes, cook logs, ratings,
/// shopping list), plus the profile-presence + iCloud-sync flags the Settings
/// view-model already holds. Fully guest-safe: every read degrades to zero /
/// false, so the dashboard renders for signed-out users.
///
/// **Public bucket is stated, not fetched.** Comments/ratings are hosted on the
/// WordPress blog; the dashboard states the fact (they are public and carry the
/// user's name + email) rather than making a live `DODNetworking` call, which
/// keeps the screen offline-clean and fast. The user's local rating count is a
/// real on-device figure and is surfaced; comments carry no live count.
@Observable
@MainActor
public final class PrivacyDashboardViewModel {

    /// The loaded inventory, or `nil` until ``load(from:hasProfile:iCloudSyncOn:)``
    /// completes. The view shows the assembled buckets once set.
    public private(set) var inventory: PrivacyInventory?

    public init(inventory: PrivacyInventory? = nil) {
        self.inventory = inventory
    }

    /// The three buckets for the current inventory (empty until loaded).
    public var buckets: [PrivacyBucket] {
        guard let inventory else { return [] }
        return PrivacyBucket.buckets(for: inventory)
    }

    /// Pull the live counts from the dependency seam and combine them with the
    /// profile-presence + iCloud-sync flags into a ``PrivacyInventory``. Each
    /// read degrades to zero on failure/absence (guest mode, previews, an
    /// unwired host) so the dashboard never shows a spurious error.
    public func load(
        from dependencies: (any SettingsDependencies)?,
        hasProfile: Bool,
        iCloudSyncOn: Bool
    ) async {
        guard let dependencies else {
            inventory = PrivacyInventory(hasProfile: hasProfile, iCloudSyncOn: iCloudSyncOn)
            return
        }
        let saved = (try? await dependencies.savedRecipeCount()) ?? 0
        let journal = ((try? await dependencies.cookLogs()) ?? []).count
        let shopping = (try? await dependencies.shoppingListItemCount()) ?? 0
        let ratings = (try? await dependencies.userRatingCount()) ?? 0
        inventory = PrivacyInventory(
            savedRecipes: saved,
            journalEntries: journal,
            shoppingListItems: shopping,
            hasProfile: hasProfile,
            ratingsPosted: ratings,
            iCloudSyncOn: iCloudSyncOn
        )
    }
}
