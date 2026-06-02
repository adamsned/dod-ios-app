import Foundation
import SwiftData

/// The ONLY model that mirrors to the user's CloudKit private database
/// (DUT-35 / DUT-6). One row per recipe (or article) the user has explicitly
/// saved, carrying just enough to render the Saved list and navigate to the
/// detail screen on any device — title, excerpt, hero image, total time, the
/// canonical URL, and a recipe-vs-article discriminator.
///
/// **Why this exists (DUT-35).** The first cut of CloudKit sync put *all six*
/// cache models (`CachedRecipe`, `CachedListPage`, `CachedImage`,
/// `CachedIngredient`, `CachedComment`, `CachedRating`) in the
/// `cloudKitDatabase: .private(...)` configuration, so the entire on-device
/// cache — including up to 200 MB of `CachedImage` photo blobs and the
/// high-churn feed/ingredient caches rewritten on every launch — was being
/// mirrored to iCloud. That over-broad scope crashed Apple's mirror on the
/// save-then-navigate path once the Production schema went live. The only
/// thing that genuinely needs to cross devices is *which posts the user
/// saved*, so sync is scoped down to this single lightweight record type;
/// every other model is local-only (`cloudKitDatabase: .none`). See
/// `RecipeStore+Containers.swift` for the two-configuration split.
///
/// **Source of truth vs. derived pin.** This type is the synced source of
/// truth for the Saved tab. `CachedRecipe.isSaved` remains a *local* pin that
/// drives LRU eviction (NFR-1), the home-screen widget, and the detail-screen
/// bookmark glyph; `RecipeStore` keeps it reconciled with the synced set
/// lazily (on `mergeDetail`) and via `toggleSaved`. Full recipe detail is NOT
/// synced — opening a recipe saved on another device is a normal cache-miss
/// that hydrates `CachedRecipe` from the network on first view.
///
/// **CloudKit-clean (DOD-CRASH-1 invariants).** Every stored attribute is
/// optional or carries a default value, and there are no `@Attribute(.unique)`
/// constraints and no `@Relationship`s (the link back to the recipe is a plain
/// `Int` id). Those are the two hard requirements for a model that opens under
/// `NSPersistentCloudKitContainer`; violating either makes the `.private`
/// container throw at open. `init` always overwrites the defaults with real
/// values; defaults are not part of the Core Data version hash, so the
/// additive V4 -> V5 migration that introduces this entity stays lightweight.
@Model
public final class SyncedSavedRecipe {

    /// WordPress post id — the stable key shared with `CachedRecipe.id`. Used
    /// to dedupe the synced set and to reconcile the local `isSaved` pin.
    public var id: Int = 0

    /// When the user saved it. Drives the Saved tab's newest-first ordering
    /// (mirrors the prior `CachedRecipe.lastViewedAt`-reverse sort intent for
    /// the saved set, but as an explicit save timestamp that is stable across
    /// devices rather than a view-order side effect).
    public var savedAt = Date.distantPast

    /// Display fields — the minimum to render a Saved card without a network
    /// fetch, so a recipe saved on another device shows immediately.
    public var title: String = ""
    public var excerptText: String = ""
    public var canonicalURLString: String = ""
    public var heroImageURLString: String?
    public var totalSeconds: Int?
    public var publishedAt = Date.distantPast

    /// Recipe-vs-article discriminator so the Saved row routes to the correct
    /// detail surface (US-37 / CL-63 parity). Full `PostKind` reconstruction
    /// still happens on detail open; this is just the routing hint.
    public var isArticle: Bool = false

    public init(
        id: Int,
        savedAt: Date = .now,
        title: String,
        excerptText: String,
        canonicalURLString: String,
        heroImageURLString: String? = nil,
        totalSeconds: Int? = nil,
        publishedAt: Date = .distantPast,
        isArticle: Bool = false
    ) {
        self.id = id
        self.savedAt = savedAt
        self.title = title
        self.excerptText = excerptText
        self.canonicalURLString = canonicalURLString
        self.heroImageURLString = heroImageURLString
        self.totalSeconds = totalSeconds
        self.publishedAt = publishedAt
        self.isArticle = isArticle
    }
}
