import AppIntents
import DODSupport
import WidgetKit

/// DUT-485 / T-905 — the user-selectable content mode for the "Latest" widget
/// (both the home-screen ``FeaturedRecipeWidget`` and the lock-screen
/// ``LatestRecipeLockScreenWidget``). Surfaced via long-press → Edit Widget.
///
/// - `auto`: today's adaptive behaviour — show whatever is newest at the top of
///   the feed, with the eyebrow reflecting whether it's a recipe or an article.
///   This is the default so existing installs don't change (AC on DUT-485).
/// - `recipes`: always show the newest post that classified as a recipe.
/// - `articles`: always show the newest post that classified as an article.
enum LatestContent: String, AppEnum {
    case auto
    case recipes
    case articles

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Latest content" }

    static var caseDisplayRepresentations: [LatestContent: DisplayRepresentation] {
        [
            .auto: "Auto (newest)",
            .recipes: "Recipes",
            .articles: "Articles",
        ]
    }
}

/// Shared configuration intent both "Latest" widgets reference from their
/// `AppIntentConfiguration`. Lives in the Widget target so both widget kinds
/// can see it. The single `content` parameter drives which snapshot entry the
/// timeline providers select (see ``LatestContent``).
struct LatestWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Latest" }

    static var description: IntentDescription {
        IntentDescription("Choose what the Latest widget shows.")
    }

    @Parameter(title: "Show", default: .auto)
    var content: LatestContent
}

extension LatestContent {
    /// DUT-485 / T-905 — selects the snapshot entry to show for this content
    /// mode. Shared by both "Latest" widgets' timeline providers so they can't
    /// drift:
    ///   - `.auto` → `snapshot.entries.first` (adaptive newest, existing behaviour)
    ///   - `.recipes` → `snapshot.latestRecipe`, falling back to `entries.first`
    ///     when the split scan didn't classify a recipe (e.g. a legacy payload
    ///     written before DUT-485, where the field is nil)
    ///   - `.articles` → `snapshot.latestArticle`, which may be nil when no
    ///     article was found; the caller then shows its graceful empty state
    ///
    /// A nil `snapshot` (App Group unavailable / first launch) yields nil and
    /// the caller falls back to its brand placeholder.
    func entry(from snapshot: WidgetSnapshot?) -> WidgetSnapshot.Entry? {
        guard let snapshot else { return nil }
        switch self {
        case .auto:
            return snapshot.entries.first
        case .recipes:
            return snapshot.latestRecipe ?? snapshot.entries.first
        case .articles:
            return snapshot.latestArticle
        }
    }
}
