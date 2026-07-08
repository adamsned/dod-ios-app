import DODDesignSystem
import DODSupport
import SwiftUI
import WidgetKit

/// Routes between the empty-state placeholder and the populated
/// `.accessoryRectangular` layout. The actual visual layer lives in
/// ``DODDesignSystem/WidgetCard``'s `LockScreen*` variants so it can be
/// snapshot-tested without linking WidgetKit (constitution §6 L4). This
/// file owns the WidgetKit-specific glue: the ``widgetURL`` tap target
/// (`dod://recipe/<id>` populated, `dod://feed` empty) and the
/// `.widgetAccentable` modifier that opts the rendered content into
/// the system's monochrome tinting pass at present-time.
///
/// Lock-screen widgets do not get per-row `Link` tap targets — the
/// `.accessoryRectangular` surface is a single tap region by design.
///
/// Spec trace: spec.md US-22, AC-22.2 (text-only render), AC-22.3
/// (tap → `dod://recipe/<id>`), AC-22.4 (empty → `dod://feed`).
struct LatestRecipeLockScreenWidgetEntryView: View {

    let entry: LatestRecipeLockScreenEntry

    var body: some View {
        Group {
            if let recipe = entry.recipe {
                WidgetCard.LockScreenRectangular(content: Self.content(from: recipe, mode: entry.content))
                    // `.widgetAccentable` is the documented opt-in for
                    // the system's per-wallpaper tint pass on accessory
                    // family widgets. The system handles the actual
                    // colour at present-time; we just declare that the
                    // text *is* tintable rather than chrome.
                    .widgetAccentable()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Self.accessibilityLabel(for: recipe, mode: entry.content))
            } else {
                // DUT-504 — mode-aware empty state: `.articles` (no article yet)
                // names the article surface rather than reusing the recipe copy.
                WidgetCard.LockScreenEmpty(
                    eyebrow: Self.emptyEyebrow(for: entry.content),
                    message: Self.emptyMessage(for: entry.content)
                )
                .widgetAccentable()
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Self.emptyAccessibilityLabel(for: entry.content))
            }
        }
        // Single chrome-level URL — `.accessoryRectangular` is one tap
        // region, so per-row `Link` (which the saved-recipes medium
        // widget uses) does not apply here. Populated → recipe detail,
        // empty → feed (both URLs already covered by US-9's
        // `WidgetDeepLinkParser` — no new parser case needed).
        .widgetURL(entry.recipe.flatMap { Self.deepLink(for: $0) } ?? URL(string: "dod://feed"))
    }

    // MARK: - Helpers

    /// DUT-504 — empty-state eyebrow. `.articles` names the article surface;
    /// otherwise the latest-recipe wording (matching `LockScreenEmpty`'s default).
    static func emptyEyebrow(for mode: LatestContent) -> String {
        mode == .articles ? "Latest Article" : "Latest Recipe"
    }

    /// DUT-504 — empty-state body copy, mode-aware.
    static func emptyMessage(for mode: LatestContent) -> String {
        mode == .articles
            ? "No recent articles yet. Open the app to catch up."
            : "Open the app to see the latest recipe."
    }

    /// DUT-504 — matching VoiceOver label for the empty tile.
    static func emptyAccessibilityLabel(for mode: LatestContent) -> String {
        mode == .articles
            ? "Latest Article widget. No recent articles. Open the app to catch up."
            : "Latest Recipe widget. Open the app to see the latest recipe."
    }

    /// Build a `dod://recipe/<id>` URL for tap-through. Mirrors
    /// `FeaturedRecipeWidgetEntryView.deepLink(for:)` so all three
    /// widgets emit recipe URLs in the same shape. DUT-652 — a placeholder entry
    /// carries `id <= 0`, whose `dod://recipe/0` tap is dead, so fall back to
    /// `dod://feed` for those (matching the empty-tile URL).
    static func deepLink(for recipe: WidgetSnapshot.Entry) -> URL? {
        guard recipe.id > 0 else { return URL(string: "dod://feed") }
        var components = URLComponents()
        components.scheme = "dod"
        components.host = "recipe"
        components.path = "/\(recipe.id)"
        return components.url
    }

    /// Map the home-screen-widget snapshot `Entry` (full payload
    /// including `heroImageURL` + `totalTimeDisplay` we don't render
    /// on the lock screen) onto the lock-screen-specific subset.
    static func content(from recipe: WidgetSnapshot.Entry, mode: LatestContent) -> WidgetCard.LockScreenContent {
        // DUT-460 / DUT-485 — adaptive eyebrow in `.auto`; fixed to the chosen
        // surface in the explicit `.recipes` / `.articles` modes.
        WidgetCard.LockScreenContent(
            eyebrow: Self.eyebrow(for: recipe, mode: mode),
            title: recipe.title
        )
    }

    /// DUT-485 — eyebrow copy. `.auto` keys off the shown post's own kind; the
    /// explicit modes key off the user's chosen surface.
    static func eyebrow(for recipe: WidgetSnapshot.Entry, mode: LatestContent) -> String {
        switch mode {
        case .auto:
            return recipe.isArticle ? "Latest Article" : "Latest Recipe"
        case .recipes:
            return "Latest Recipe"
        case .articles:
            return "Latest Article"
        }
    }

    static func accessibilityLabel(for recipe: WidgetSnapshot.Entry, mode: LatestContent) -> String {
        let eyebrow = Self.eyebrow(for: recipe, mode: mode).lowercased()
        if recipe.excerpt.isEmpty {
            return "\(eyebrow): \(recipe.title)."
        }
        return "\(eyebrow): \(recipe.title). \(recipe.excerpt)"
    }
}
