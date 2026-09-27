import Foundation

// DUT-160 — pure data types + assembly logic for the Privacy Dashboard
// ("Where your data lives"). Kept free of SwiftUI + persistence so the L1 unit
// suite can pin the bucket rows / copy / counts without a `RecipeStore` or a
// rendered view. `PrivacyDashboardViewModel` loads a ``PrivacyInventory`` from
// the `SettingsDependencies` seam; every string + row assembled below is a
// pure function of that inventory.

/// The live, on-device inventory the dashboard groups by location. Populated
/// by ``PrivacyDashboardViewModel/load(from:hasProfile:iCloudSyncOn:)`` from the
/// `SettingsDependencies` reads (all guest-safe — no account required).
public struct PrivacyInventory: Equatable, Sendable {

    /// Recipes/articles the user has explicitly saved (the ONLY category that
    /// mirrors to iCloud, and only when iCloud Sync is on — see `SyncedSavedRecipe`).
    public var savedRecipes: Int
    /// Cooking-journal (cook-log) entries. Local-only.
    public var journalEntries: Int
    /// Items on the Shopping List. Local-only (App Group `UserDefaults`).
    public var shoppingListItems: Int
    /// Whether an on-device profile exists (name / email / photo). Local-only.
    public var hasProfile: Bool
    /// Recipes this device has submitted a public star rating for.
    public var ratingsPosted: Int
    /// Whether iCloud Sync is currently on.
    public var iCloudSyncOn: Bool

    public init(
        savedRecipes: Int = 0,
        journalEntries: Int = 0,
        shoppingListItems: Int = 0,
        hasProfile: Bool = false,
        ratingsPosted: Int = 0,
        iCloudSyncOn: Bool = false
    ) {
        self.savedRecipes = savedRecipes
        self.journalEntries = journalEntries
        self.shoppingListItems = shoppingListItems
        self.hasProfile = hasProfile
        self.ratingsPosted = ratingsPosted
        self.iCloudSyncOn = iCloudSyncOn
    }
}

/// One data category inside a bucket: a Title-Case label, a short location /
/// count value, and a sentence-case plain-language explanation revealed on tap.
public struct PrivacyDataRow: Identifiable, Equatable, Sendable {
    public let id: String
    /// Title Case (it labels a data category).
    public let title: String
    /// Short value shown trailing the title (a count or a location word).
    public let detail: String
    /// Sentence-case plain-language explanation, revealed one-tap.
    public let explanation: String

    public init(id: String, title: String, detail: String, explanation: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.explanation = explanation
    }
}

/// The three location buckets, in display order.
public enum PrivacyBucketKind: String, CaseIterable, Sendable {
    case onDevice
    case iCloud
    case publicBlog
}

/// A titled bucket grouping the categories that live in one location.
public struct PrivacyBucket: Identifiable, Equatable, Sendable {
    public let id: PrivacyBucketKind
    /// Title Case section heading.
    public let title: String
    /// Sentence-case one-line summary under the heading.
    public let summary: String
    public let rows: [PrivacyDataRow]

    public init(id: PrivacyBucketKind, title: String, summary: String, rows: [PrivacyDataRow]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.rows = rows
    }
}

extension PrivacyBucket {

    /// Assemble all three buckets from a live inventory. Pure — the L1 suite
    /// asserts the rows / counts / copy directly off a constructed inventory.
    public static func buckets(for inventory: PrivacyInventory) -> [PrivacyBucket] {
        [onDevice(inventory), iCloud(inventory), publicBlog(inventory)]
    }

    /// On device (SwiftData + App Group): saved recipes, cooking journal,
    /// shopping list, profile. Everything here is guest-safe and stays on the
    /// phone unless the specific iCloud-Sync exception applies (saved recipes).
    static func onDevice(_ inventory: PrivacyInventory) -> PrivacyBucket {
        let rows = [
            PrivacyDataRow(
                id: "onDevice.saved",
                title: "Saved Recipes",
                detail: countDetail(inventory.savedRecipes, singular: "recipe", plural: "recipes"),
                explanation: "The recipes and articles you save stay on this iPhone. "
                    + "They sync to your other Apple devices only when you turn on iCloud sync."
            ),
            PrivacyDataRow(
                id: "onDevice.journal",
                title: "Cooking Journal",
                detail: countDetail(inventory.journalEntries, singular: "entry", plural: "entries"),
                explanation: "Your cooking journal stays only on this iPhone. "
                    + "It is not part of iCloud sync, so it never leaves this device."
            ),
            PrivacyDataRow(
                id: "onDevice.shopping",
                title: "Shopping List",
                detail: countDetail(inventory.shoppingListItems, singular: "item", plural: "items"),
                explanation: "Your shopping list stays only on this iPhone. "
                    + "It is not part of iCloud sync."
            ),
            PrivacyDataRow(
                id: "onDevice.profile",
                title: "Profile",
                detail: inventory.hasProfile ? "Set up" : "Not set up",
                explanation: "Your name, email, and photo stay on this iPhone. "
                    + "They are not published anywhere and are not part of iCloud sync."
            ),
        ]
        return PrivacyBucket(
            id: .onDevice,
            title: "On Device",
            summary: "This data lives on your iPhone.",
            rows: rows
        )
    }

    /// Your iCloud (Private): which of the on-device categories currently sync.
    /// Only saved recipes mirror, and only while sync is on.
    static func iCloud(_ inventory: PrivacyInventory) -> PrivacyBucket {
        let rows: [PrivacyDataRow]
        if inventory.iCloudSyncOn {
            rows = [
                PrivacyDataRow(
                    id: "iCloud.saved",
                    title: "Saved Recipes",
                    detail: "Syncing",
                    explanation: "iCloud sync is on, so the list of recipes you saved is stored in "
                        + "your private iCloud. Only you can see it. Your cooking journal, "
                        + "shopping list, and profile stay on this device."
                )
            ]
        } else {
            rows = [
                PrivacyDataRow(
                    id: "iCloud.off",
                    title: "iCloud Sync",
                    detail: "Off",
                    explanation: "iCloud sync is off, so nothing is stored in iCloud right now. "
                        + "Turn it on to back up your saved recipes to your private iCloud, "
                        + "where only you can see them."
                )
            ]
        }
        return PrivacyBucket(
            id: .iCloud,
            title: "iCloud (Private)",
            summary: inventory.iCloudSyncOn
                ? "This data is stored in your private iCloud, visible only to you."
                : "iCloud sync is off, so nothing is stored in iCloud right now.",
            rows: rows
        )
    }

    /// Public on the blog: comments + ratings, which carry the user's name and
    /// email. Stated as fact (no live network fetch — see the view model note).
    static func publicBlog(_ inventory: PrivacyInventory) -> PrivacyBucket {
        let rows = [
            PrivacyDataRow(
                id: "public.comments",
                title: "Comments",
                detail: "Public",
                explanation: "Comments you post appear publicly on dutchovendaddy.com "
                    + "and show your name and email."
            ),
            PrivacyDataRow(
                id: "public.ratings",
                title: "Ratings",
                detail: inventory.ratingsPosted > 0
                    ? countDetail(inventory.ratingsPosted, singular: "posted", plural: "posted")
                    : "Public",
                explanation: "Star ratings you submit appear publicly on dutchovendaddy.com "
                    + "and show your name and email."
            ),
        ]
        return PrivacyBucket(
            id: .publicBlog,
            title: "Public (Blog)",
            summary: "This is publicly visible on dutchovendaddy.com and carries your name and email.",
            rows: rows
        )
    }

    /// "N thing" / "N things" (or "N posted"), zero-safe. Pure helper so the
    /// L1 suite can pin the pluralization.
    static func countDetail(_ count: Int, singular: String, plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }
}
