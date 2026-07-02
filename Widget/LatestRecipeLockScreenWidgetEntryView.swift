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
                WidgetCard.LockScreenRectangular(content: Self.content(from: recipe))
                    // `.widgetAccentable` is the documented opt-in for
                    // the system's per-wallpaper tint pass on accessory
                    // family widgets. The system handles the actual
                    // colour at present-time; we just declare that the
                    // text *is* tintable rather than chrome.
                    .widgetAccentable()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Self.accessibilityLabel(for: recipe))
            } else {
                WidgetCard.LockScreenEmpty()
                    .widgetAccentable()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "Latest Recipe widget. Open the app to see the latest recipe."
                    )
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

    /// Build a `dod://recipe/<id>` URL for tap-through. Mirrors
    /// `FeaturedRecipeWidgetEntryView.deepLink(for:)` so all three
    /// widgets emit recipe URLs in the same shape.
    static func deepLink(for recipe: WidgetSnapshot.Entry) -> URL? {
        var components = URLComponents()
        components.scheme = "dod"
        components.host = "recipe"
        components.path = "/\(recipe.id)"
        return components.url
    }

    /// Map the home-screen-widget snapshot `Entry` (full payload
    /// including `heroImageURL` + `totalTimeDisplay` we don't render
    /// on the lock screen) onto the lock-screen-specific subset.
    static func content(from recipe: WidgetSnapshot.Entry) -> WidgetCard.LockScreenContent {
        // DUT-460 — adaptive eyebrow: the latest post is a recipe or an article.
        WidgetCard.LockScreenContent(
            eyebrow: recipe.isArticle ? "Latest Article" : "Latest Recipe",
            title: recipe.title
        )
    }

    static func accessibilityLabel(for recipe: WidgetSnapshot.Entry) -> String {
        if recipe.excerpt.isEmpty {
            return "Latest recipe: \(recipe.title)."
        }
        return "Latest recipe: \(recipe.title). \(recipe.excerpt)"
    }
}
