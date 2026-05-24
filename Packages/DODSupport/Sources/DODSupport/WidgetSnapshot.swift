import Foundation

/// Wire format the main app writes and the home-screen widget extension reads.
///
/// The widget runs in its own process and cannot reach the app's SwiftData
/// store — instead the app drops a tiny snapshot of the top-of-feed into a
/// shared App Group container after every successful feed load. The widget's
/// `TimelineProvider` reads that snapshot on each refresh.
///
/// Spec trace: spec.md US-9 (home-screen widget), AC-9.3 (refresh on feed
/// update).
public struct WidgetSnapshot: Codable, Sendable, Equatable {

    /// Version tag — bumped only when ``Entry``'s shape changes
    /// incompatibly. The reader returns nil on mismatch instead of crashing,
    /// which means a user installing a new widget binary against an older app
    /// payload (or vice-versa during a phased rollout) sees the placeholder
    /// rather than garbage.
    public static let currentVersion = 1

    public let version: Int
    public let writtenAt: Date
    public let entries: [Entry]

    public init(version: Int = WidgetSnapshot.currentVersion, writtenAt: Date, entries: [Entry]) {
        self.version = version
        self.writtenAt = writtenAt
        self.entries = entries
    }

    public struct Entry: Codable, Sendable, Equatable, Identifiable {
        public let id: Int
        public let title: String
        public let excerpt: String
        public let heroImageURL: URL?
        public let canonicalURL: URL?
        public let publishedAt: Date
        public let totalTimeDisplay: String?

        public init(
            id: Int,
            title: String,
            excerpt: String,
            heroImageURL: URL?,
            canonicalURL: URL?,
            publishedAt: Date,
            totalTimeDisplay: String?
        ) {
            self.id = id
            self.title = title
            self.excerpt = excerpt
            self.heroImageURL = heroImageURL
            self.canonicalURL = canonicalURL
            self.publishedAt = publishedAt
            self.totalTimeDisplay = totalTimeDisplay
        }
    }
}

/// Parser for the `dod://` deep-link scheme the home-screen widget uses to
/// open recipes in the app (spec.md US-9 AC-9.2). Lives in DODSupport so it
/// can be unit-tested without depending on the app target.
///
/// Recognized shapes:
///   - `dod://recipe/<id>` — open the recipe with the given WP ID
///   - `dod://feed` — open or switch to the Feed tab
///   - `dod://saved` — open or switch to the Saved tab (US-17 / AC-17.4,
///     AC-17.5; CL-29). Both the empty-state placeholder and any tap on
///     widget chrome (outside a recipe row) of the saved-recipes widget
///     fire this URL.
public enum WidgetDeepLinkParser {

    public enum Route: Equatable, Sendable {
        case recipe(id: Int)
        case feed
        case saved
    }

    /// Returns `nil` for any URL we don't recognize so callers never spawn
    /// navigation on hostile or malformed input.
    public static func parse(_ url: URL) -> Route? {
        guard url.scheme?.lowercased() == "dod" else { return nil }
        let host = url.host?.lowercased() ?? ""
        switch host {
        case "recipe":
            let trimmed = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let id = Int(trimmed), id > 0 else { return nil }
            return .recipe(id: id)
        case "feed":
            return .feed
        case "saved":
            // `dod://saved` only — reject any path-bearing variant
            // (`dod://saved/`, `dod://saved/123`, etc.). The widget
            // chrome and empty-state placeholder both emit the bare URL;
            // anything with a path is malformed and ignored. AC-17.8.
            let trimmed = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard trimmed.isEmpty else { return nil }
            return .saved
        default:
            return nil
        }
    }
}

/// Identifiers shared by the app and the widget extension.
public enum WidgetSnapshotConfig {

    /// App Group container both targets join. Must match the
    /// `com.apple.security.application-groups` entitlement declared in both
    /// targets and the matching group provisioned in the developer portal.
    public static let appGroupIdentifier = "group.com.dutchovendaddy.DODApp"

    /// UserDefaults key under the App Group suite. We use a single key so
    /// multiple widget kinds (small, medium) all read the same payload.
    public static let userDefaultsKey = "dod.widget.featuredRecipes.v1"

    /// Cap on how many entries the snapshot stores. The widget only displays
    /// one at a time today, but writing five gives us headroom for a rotating
    /// timeline without changing the wire format.
    public static let maxEntries = 5
}

/// Reads + writes ``WidgetSnapshot`` to the shared App Group's UserDefaults.
///
/// Both processes construct one of these; the writer is the main app (after
/// every successful feed load) and the reader is the widget extension's
/// `TimelineProvider`. UserDefaults (not a JSON file) is intentional —
/// UserDefaults backed by an App Group suite handles cross-process
/// coordination for us and is the documented Apple-recommended path for
/// snapshots this small (low single-digit KB).
///
/// `@unchecked Sendable` is safe here: every property is a `let`, and
/// `UserDefaults` itself is documented as thread-safe (Apple's docs note
/// "you can use a single instance from multiple threads"). The Foundation
/// header just hasn't been audited for Swift 6 Sendability yet.
public struct WidgetSnapshotStore: @unchecked Sendable {

    // `internal` rather than `private` so the saved-recipes extension in
    // SavedRecipesWidgetSnapshot.swift can reuse the same UserDefaults
    // suite — both widgets share an App Group, only their keys differ.
    let defaults: UserDefaults
    private let key: String

    /// Backing store the saved-recipes extension methods write to. Same
    /// `UserDefaults` instance — exposed under a friendlier name so the
    /// extension reads as if it owned its own field.
    var savedRecipesDefaults: UserDefaults { defaults }

    public init?(
        suiteName: String = WidgetSnapshotConfig.appGroupIdentifier,
        key: String = WidgetSnapshotConfig.userDefaultsKey
    ) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return nil
        }
        self.defaults = defaults
        self.key = key
    }

    /// Test-only initializer that takes a pre-built `UserDefaults` (e.g. a
    /// `UserDefaults(suiteName: <temporary name>)` so tests don't pollute
    /// either the App Group suite or `.standard`).
    public init(defaults: UserDefaults, key: String = WidgetSnapshotConfig.userDefaultsKey) {
        self.defaults = defaults
        self.key = key
    }

    /// Persist a fresh snapshot. Always succeeds — UserDefaults swallows
    /// write failures internally — so callers can treat this as fire-and-
    /// forget. Returns the encoded `Data` for tests that want to assert on
    /// the payload directly.
    @discardableResult
    public func write(_ snapshot: WidgetSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        defaults.set(data, forKey: key)
        return data
    }

    /// Convenience: build a snapshot from a list of entries and write it.
    @discardableResult
    public func write(entries: [WidgetSnapshot.Entry], now: Date = Date()) throws -> Data {
        let trimmed = Array(entries.prefix(WidgetSnapshotConfig.maxEntries))
        let snapshot = WidgetSnapshot(writtenAt: now, entries: trimmed)
        return try write(snapshot)
    }

    /// Returns the most-recently-written snapshot, or nil if nothing has
    /// been written yet OR the persisted version doesn't match this
    /// binary's expected version.
    public func read() -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) else {
            return nil
        }
        guard snapshot.version == WidgetSnapshot.currentVersion else { return nil }
        return snapshot
    }

    /// Test helper: drop the persisted snapshot.
    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
