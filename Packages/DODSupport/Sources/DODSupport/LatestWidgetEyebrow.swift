import Foundation

/// The three user-selectable content modes for the "Latest" widget family
/// (home-screen `FeaturedRecipeWidget` + the lock-screen
/// `LatestRecipeLockScreenWidget`). Mirrors the Widget target's
/// `LatestContent` `AppEnum` case-for-case; kept as a plain enum here (no
/// `AppIntents` import) so the eyebrow-resolution logic below is usable from
/// a `swift test` target without linking WidgetKit/AppIntents. DUT-485 /
/// T-905.
public enum LatestWidgetContentMode: Sendable {
    case auto
    case recipes
    case articles
}

/// Which "kind" label the Latest widget's eyebrow / VoiceOver prefix should
/// use for a resolved entry. Callers format their own copy from this
/// (`"Latest Recipe"` vs. `"Latest Article"` for the visible eyebrow,
/// `"Latest recipe"` vs. `"Latest article"` for the spoken prefix) — this
/// type only decides recipe-vs-article, not the string casing.
public enum LatestWidgetEyebrowKind: Sendable, Equatable {
    case recipe
    case article
}

extension LatestWidgetEyebrowKind {

    /// Resolves the eyebrow kind for an entry shown under `mode`.
    ///
    /// DUT-567 — `LatestContent.entry(from:)`'s `.recipes` case falls back
    /// to `entries.first` when the split classification scan found no
    /// recipe (legacy payload written before DUT-485, or the scan cap hit
    /// before a recipe turned up). That fallback entry can be an article,
    /// so `.recipes` must key off `isArticle` exactly like `.auto` does —
    /// an article must never be labeled "Latest Recipe." `.articles` is
    /// always `.article` because that mode only ever surfaces
    /// `snapshot.latestArticle`.
    ///
    /// Both "Latest" widgets (home-screen + lock-screen) route their
    /// eyebrow AND accessibility-label copy through this single function so
    /// they can't drift out of sync with each other or with DUT-567's fix.
    public static func resolve(isArticle: Bool, mode: LatestWidgetContentMode) -> LatestWidgetEyebrowKind {
        switch mode {
        case .auto, .recipes:
            return isArticle ? .article : .recipe
        case .articles:
            return .article
        }
    }
}
