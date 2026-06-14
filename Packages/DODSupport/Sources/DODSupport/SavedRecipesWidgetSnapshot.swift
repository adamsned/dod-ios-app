import Foundation

/// Wire format the main app writes and the saved-recipes home-screen widget
/// extension reads.
///
/// Same pattern as ``WidgetSnapshot`` (the featured-recipe widget): the
/// widget runs in its own process and cannot reach the app's SwiftData
/// store, so the app drops a tiny snapshot of the most-recently-saved
/// recipes into a shared App Group container whenever the saved set
/// changes. The widget's `TimelineProvider` reads that snapshot on each
/// refresh.
///
/// Spec trace: spec.md US-17 (home-screen widget for saved recipes),
/// AC-17.3 (snapshot payload + container file), AC-17.6 (schema versioning
/// and clear behavior).
public struct SavedRecipesWidgetSnapshot: Codable, Sendable, Equatable {

    /// Version tag — bumped only when ``Entry``'s shape changes
    /// incompatibly. The reader returns nil on mismatch instead of
    /// crashing, which means a user installing a new widget binary against
    /// an older app payload (or vice-versa during a phased rollout) sees
    /// the placeholder rather than garbage. Mirrors the same approach as
    /// ``WidgetSnapshot/currentVersion``.
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let writtenAt: Date
    public let entries: [Entry]

    public init(
        schemaVersion: Int = SavedRecipesWidgetSnapshot.currentSchemaVersion,
        writtenAt: Date,
        entries: [Entry]
    ) {
        self.schemaVersion = schemaVersion
        self.writtenAt = writtenAt
        self.entries = entries
    }

    public struct Entry: Codable, Sendable, Equatable, Identifiable {
        /// WordPress recipe ID — same identifier used by the
        /// `dod://recipe/<id>` deep link (US-9 / `WidgetDeepLinkParser`).
        public let recipeID: Int
        public let title: String
        public let canonicalURL: URL
        /// Filename (not full path) of the hero image previously cached by
        /// the host app into the shared App Group container. `nil` when no
        /// image has been cached yet — the widget renders its empty-image
        /// placeholder rather than chasing a network fetch (AC-17.6
        /// forbids widget-side network).
        public let heroImageFilename: String?
        /// When the user saved this recipe. The store sorts by this field
        /// descending at write time so the widget always shows the
        /// most-recently-saved first.
        public let savedAt: Date

        public var id: Int { recipeID }

        public init(
            recipeID: Int,
            title: String,
            canonicalURL: URL,
            heroImageFilename: String?,
            savedAt: Date
        ) {
            self.recipeID = recipeID
            self.title = title
            self.canonicalURL = canonicalURL
            self.heroImageFilename = heroImageFilename
            self.savedAt = savedAt
        }
    }
}

/// Identifiers shared by the app and the saved-recipes widget extension.
///
/// Kept separate from ``WidgetSnapshotConfig`` so the two widgets'
/// payloads never collide on the same UserDefaults key. The App Group
/// identifier is shared — only the key differs, which matches Apple's
/// recommended single-suite, multi-key layout for related widgets.
public enum SavedRecipesWidgetSnapshotConfig {

    /// UserDefaults key under the App Group suite. Distinct from the
    /// featured-widget key so the two widgets' payloads coexist without
    /// stomping each other.
    public static let userDefaultsKey = "dod.widget.savedRecipes.v1"

    /// Cap on how many entries the snapshot stores. T-768 / CL-165 (DUT-74):
    /// the widget ships in three sizes — small (1), medium (3), large (up to
    /// 5). All sizes read the same payload and take `prefix(N)` client-side
    /// based on `widgetFamily`, so the cap is the largest size's need (5).
    public static let maxEntries = 5
}

extension WidgetSnapshotStore {

    /// Persist a fresh saved-recipes snapshot. Always succeeds —
    /// UserDefaults swallows write failures internally — so callers can
    /// treat this as fire-and-forget. Returns the encoded `Data` for tests
    /// that want to assert on the payload directly.
    ///
    /// The saved-recipes payload lives at a separate UserDefaults key
    /// (``SavedRecipesWidgetSnapshotConfig/userDefaultsKey``) from the
    /// featured-recipe payload so the two widgets' writes never collide.
    @discardableResult
    public func writeSavedRecipes(_ snapshot: SavedRecipesWidgetSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        savedRecipesDefaults.set(data, forKey: SavedRecipesWidgetSnapshotConfig.userDefaultsKey)
        return data
    }

    /// Convenience: build a saved-recipes snapshot from a list of entries
    /// and write it. Caps at ``SavedRecipesWidgetSnapshotConfig/maxEntries``
    /// and sorts by `savedAt` descending so the widget always shows the
    /// most-recently-saved first (AC-17.3).
    @discardableResult
    public func writeSavedRecipes(
        entries: [SavedRecipesWidgetSnapshot.Entry],
        now: Date = Date()
    ) throws -> Data {
        let sorted = entries.sorted { $0.savedAt > $1.savedAt }
        let trimmed = Array(sorted.prefix(SavedRecipesWidgetSnapshotConfig.maxEntries))
        let snapshot = SavedRecipesWidgetSnapshot(writtenAt: now, entries: trimmed)
        return try writeSavedRecipes(snapshot)
    }

    /// Returns the most-recently-written saved-recipes snapshot, or nil if
    /// nothing has been written yet OR the persisted schemaVersion doesn't
    /// match this binary. The widget extension falls back to its empty
    /// placeholder (AC-17.5) when this returns nil.
    public func readSavedRecipes() -> SavedRecipesWidgetSnapshot? {
        guard
            let data = savedRecipesDefaults.data(
                forKey: SavedRecipesWidgetSnapshotConfig.userDefaultsKey
            )
        else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(SavedRecipesWidgetSnapshot.self, from: data) else {
            return nil
        }
        guard snapshot.schemaVersion == SavedRecipesWidgetSnapshot.currentSchemaVersion else {
            return nil
        }
        return snapshot
    }

    /// Drop the persisted saved-recipes payload. Called by the host app
    /// when the saved set transitions to empty so the widget can show its
    /// empty-state placeholder (T-322 will wire the call site;
    /// `readSavedRecipes()` returning nil drives the placeholder either
    /// way).
    public func clearSavedRecipes() {
        savedRecipesDefaults.removeObject(forKey: SavedRecipesWidgetSnapshotConfig.userDefaultsKey)
    }
}
