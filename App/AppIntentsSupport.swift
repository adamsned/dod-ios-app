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

    nonisolated(unsafe) private static var _actions: AppIntentActions?

    /// DUT-1388 — registered once from `AppDependencies.bootstrap()`.
    static func register(actions: AppIntentActions) {
        lock.lock()
        defer { lock.unlock() }
        _actions = actions
    }

    /// The network + side-effect actions, or nil before bootstrap (callers
    /// degrade to store-only behavior or a "try again" dialog).
    static var actions: AppIntentActions? {
        lock.lock()
        defer { lock.unlock() }
        return _actions
    }
}

/// DUT-1388 — what the Siri / Shortcuts intents need beyond the store: the
/// network (search the whole site, fetch a recipe that was never opened) and the
/// app's own save + Shopping List paths, so a Siri "Save this recipe" has the
/// exact side effects of a tap (widget republish, hero pin, ingredient parse).
/// Built by `AppDependencies.registerAppIntents()`.
struct AppIntentActions: Sendable {
    /// Site search (WP `search`), unranked.
    let searchRecipes: @Sendable (String) async throws -> [RecipeListItem]
    /// One post by id, for a recipe that isn't in the local cache.
    let fetchPost: @Sendable (Int) async throws -> RecipeListItem
    /// The card long-press save path (`TabStack.saveFromCard`). It TOGGLES,
    /// so callers check `isSaved` first. Returns whether the write succeeded.
    let save: @MainActor @Sendable (RecipeListItem) async -> Bool
    /// The Shopping List appender (hydrates ingredients when needed).
    let addToShoppingList: @MainActor @Sendable (Recipe) async -> AddToShoppingListResult
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

    /// DUT-1388 — a network hit (site search / fetch by id) as a payload.
    public static func fromListItem(_ item: RecipeListItem) -> RecipeEntityPayload {
        RecipeEntityPayload(
            id: item.id,
            title: item.title,
            excerpt: item.excerpt,
            heroImage: item.heroImage,
            canonicalURL: item.canonicalURL
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
