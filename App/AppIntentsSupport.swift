import DODDomain
import DODPersistence
import Foundation

/// Process-wide accessor for the live RecipeStore that App Intents and
/// Spotlight indexing reach into.
///
/// App Intents and `IntentEntityQuery` execute in the host app's process but
/// outside any SwiftUI view tree, so they cannot read `@State` or the
/// `@MainActor` `AppDependencies` instance directly. Stashing the live store
/// in a lock-protected box at app launch is the simplest bridge that avoids
/// rebuilding a SwiftData container per intent invocation.
///
/// Spec trace: US-10 / AC-10.1 (entity lookup) and AC-10.3 (Spotlight
/// indexing). Constitution §5 singletons carveout applies — RecipeStore is
/// process-wide infrastructure already, this just exposes it by name.
public enum AppIntentEnvironment {

    private static let lock = NSLock()
    nonisolated(unsafe) private static var _store: RecipeStore?

    /// Registered once from `AppDependencies.bootstrap()`.
    public static func register(store: RecipeStore) {
        lock.lock()
        defer { lock.unlock() }
        _store = store
    }

    /// Returns the registered store, or nil if intents fired before the app
    /// finished bootstrap (Spotlight can theoretically invoke us very early).
    /// Callers must handle nil — typically by returning an empty result set
    /// rather than crashing.
    public static var store: RecipeStore? {
        lock.lock()
        defer { lock.unlock() }
        return _store
    }
}

/// Lightweight projection of a recipe used by App Intents / Spotlight.
/// We deliberately avoid leaking SwiftData `@Model` types through the entity
/// surface — Sendable value types are easier to reason about across the
/// intent / app boundary.
public struct RecipeEntityPayload: Sendable, Hashable, Identifiable {
    public let id: Int
    public let title: String
    public let excerpt: String
    public let heroImage: URL?
    public let canonicalURL: URL?

    public init(id: Int, title: String, excerpt: String, heroImage: URL?, canonicalURL: URL?) {
        self.id = id
        self.title = title
        self.excerpt = excerpt
        self.heroImage = heroImage
        self.canonicalURL = canonicalURL
    }

    /// Map a Domain.Recipe (what RecipeStore vends) into the lighter entity
    /// payload. Pure for testability.
    public static func fromRecipe(_ recipe: Recipe) -> RecipeEntityPayload {
        RecipeEntityPayload(
            id: recipe.id,
            title: recipe.title,
            excerpt: recipe.excerpt,
            heroImage: recipe.heroImage,
            canonicalURL: recipe.canonicalURL
        )
    }

    /// Convert back to a RecipeListItem so we can navigate to the existing
    /// detail screen via `RecipeRoute.recipe(item:)`.
    public func toListItem() -> RecipeListItem {
        RecipeListItem(
            id: id,
            title: title,
            excerpt: excerpt,
            heroImage: heroImage,
            publishedAt: .distantPast,
            totalTimeDisplay: nil,
            canonicalURL: canonicalURL
        )
    }
}
