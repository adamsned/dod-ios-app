import DODDesignSystem
import DODSupport
import SwiftUI
import WidgetKit

/// Routes between the empty-state placeholder and the populated layouts
/// based on the widget family the user installed. The actual visual layer
/// is in `DODDesignSystem.WidgetCard` so it can be snapshot-tested without
/// linking WidgetKit (constitution §6 L4).
struct FeaturedRecipeWidgetEntryView: View {

    @Environment(\.widgetFamily) private var family
    let entry: FeaturedRecipeEntry

    var body: some View {
        Group {
            if let recipe = entry.recipe {
                switch family {
                case .systemLarge:
                    // T-768 / CL-165 (DUT-74) — large = hero-forward layout.
                    WidgetCard.FeaturedLarge(content: Self.content(from: recipe, mode: entry.content))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Self.mediumAccessibilityLabel(for: recipe, mode: entry.content))
                case .systemMedium:
                    WidgetCard.Medium(content: Self.content(from: recipe, mode: entry.content))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Self.mediumAccessibilityLabel(for: recipe, mode: entry.content))
                default:
                    WidgetCard.Small(content: Self.content(from: recipe, mode: entry.content))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Self.smallAccessibilityLabel(for: recipe, mode: entry.content))
                }
            } else {
                // DUT-504 — the empty state is mode-aware: in `.articles` mode
                // (no article yet) it names the article surface instead of
                // reusing the "featured recipe" copy the recipe placeholder used
                // to lie with.
                WidgetCard.Placeholder(message: Self.emptyMessage(for: entry.content))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Self.emptyAccessibilityLabel(for: entry.content))
            }
        }
        // Deep link into the app: `dod://recipe/<id>` matches the URL the
        // RootView's `onOpenURL` handler routes (AC-9.2). When the recipe
        // is nil we open to the feed instead so the user lands somewhere
        // useful rather than nowhere.
        .widgetURL(entry.recipe.flatMap { Self.deepLink(for: $0) } ?? URL(string: "dod://feed"))
    }

    /// DUT-504 — empty-state body copy. `.articles` names the (missing) article
    /// surface; every other mode keeps the original featured-recipe wording.
    static func emptyMessage(for mode: LatestContent) -> String {
        switch mode {
        case .articles:
            return "No recent articles yet. Open the app to catch up."
        case .auto, .recipes:
            return "Open the app to see today's featured recipe here."
        }
    }

    /// DUT-504 — matching VoiceOver label for the empty tile.
    static func emptyAccessibilityLabel(for mode: LatestContent) -> String {
        switch mode {
        case .articles:
            return "Dutch Oven Daddy widget. No recent articles. Open the app to catch up."
        case .auto, .recipes:
            return "Dutch Oven Daddy widget. Open the app to load today's featured recipe."
        }
    }

    /// Build a `dod://recipe/<id>` URL for tap-through.
    static func deepLink(for recipe: WidgetSnapshot.Entry) -> URL? {
        var components = URLComponents()
        components.scheme = "dod"
        components.host = "recipe"
        components.path = "/\(recipe.id)"
        return components.url
    }

    static func content(from recipe: WidgetSnapshot.Entry, mode: LatestContent) -> WidgetCard.Content {
        // Resolve the bridged filename into a `file://` URL pointing at
        // the shared App Group container (spec.md AC-21.3). `AsyncImage`
        // against a `file://` URL is a local read — not a network fetch
        // — so the widget extension keeps its no-network contract
        // (constitution §9 implicit, AC-17.6 analog). When the filename
        // is nil OR the file is absent OR the App Group container can't
        // be located, `WidgetCard.Hero` renders the gradient placeholder
        // fallback (AC-21.3, AC-21.5 — placeholder behavior unchanged).
        let heroFileURL = recipe.heroImageFilename.flatMap {
            WidgetImageBridge.fileURL(forFilename: $0)
        }
        return WidgetCard.Content(
            title: recipe.title,
            excerpt: recipe.excerpt,
            heroImageURL: heroFileURL,
            totalTimeDisplay: recipe.totalTimeDisplay,
            eyebrow: Self.eyebrow(for: recipe, mode: mode)
        )
    }

    /// DUT-460 / DUT-485 — the eyebrow copy. In `.auto` mode it stays adaptive,
    /// keyed off the shown post's own kind (was hardcoded "New on DOD"). In the
    /// explicit `.recipes` / `.articles` modes the user has fixed the surface,
    /// so we key the eyebrow off the selected mode instead.
    static func eyebrow(for recipe: WidgetSnapshot.Entry, mode: LatestContent) -> String {
        switch mode {
        case .auto:
            return recipe.isArticle ? "Latest Article" : "Latest Recipe"
        case .recipes:
            // DUT-567 — the `.recipes` fallback (`latestRecipe ?? entries.first`)
            // can resolve to an article when the split scan didn't classify a
            // recipe (legacy payload / no classifier). Key the eyebrow off the
            // resolved entry's own kind so an article is never mislabeled
            // "Latest Recipe."
            return recipe.isArticle ? "Latest Article" : "Latest Recipe"
        case .articles:
            return "Latest Article"
        }
    }

    /// DUT-507 — the spoken prefix mirrors the visible `eyebrow(for:mode:)`
    /// branch so VoiceOver says "Latest article" in `.articles` mode instead of
    /// hardcoding "Today's recipe" (matching the lock-screen widget's approach).
    static func spokenPrefix(for recipe: WidgetSnapshot.Entry, mode: LatestContent) -> String {
        switch mode {
        case .auto:
            return recipe.isArticle ? "Latest article" : "Latest recipe"
        case .recipes:
            return "Latest recipe"
        case .articles:
            return "Latest article"
        }
    }

    static func smallAccessibilityLabel(for recipe: WidgetSnapshot.Entry, mode: LatestContent) -> String {
        let prefix = Self.spokenPrefix(for: recipe, mode: mode)
        if let totalTime = recipe.totalTimeDisplay {
            return "\(prefix): \(recipe.title). \(totalTime)."
        } else {
            return "\(prefix): \(recipe.title)."
        }
    }

    static func mediumAccessibilityLabel(for recipe: WidgetSnapshot.Entry, mode: LatestContent) -> String {
        var parts = ["\(Self.spokenPrefix(for: recipe, mode: mode)): \(recipe.title)"]
        if !recipe.excerpt.isEmpty { parts.append(recipe.excerpt) }
        if let totalTime = recipe.totalTimeDisplay { parts.append(totalTime) }
        return parts.joined(separator: ". ") + "."
    }
}
