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
                    WidgetCard.FeaturedLarge(content: Self.content(from: recipe))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Self.mediumAccessibilityLabel(for: recipe))
                case .systemMedium:
                    WidgetCard.Medium(content: Self.content(from: recipe))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Self.mediumAccessibilityLabel(for: recipe))
                default:
                    WidgetCard.Small(content: Self.content(from: recipe))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Self.smallAccessibilityLabel(for: recipe))
                }
            } else {
                WidgetCard.Placeholder()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "Dutch Oven Daddy widget. Open the app to load today's featured recipe."
                    )
            }
        }
        // Deep link into the app: `dod://recipe/<id>` matches the URL the
        // RootView's `onOpenURL` handler routes (AC-9.2). When the recipe
        // is nil we open to the feed instead so the user lands somewhere
        // useful rather than nowhere.
        .widgetURL(entry.recipe.flatMap { Self.deepLink(for: $0) } ?? URL(string: "dod://feed"))
    }

    /// Build a `dod://recipe/<id>` URL for tap-through.
    static func deepLink(for recipe: WidgetSnapshot.Entry) -> URL? {
        var components = URLComponents()
        components.scheme = "dod"
        components.host = "recipe"
        components.path = "/\(recipe.id)"
        return components.url
    }

    static func content(from recipe: WidgetSnapshot.Entry) -> WidgetCard.Content {
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
            totalTimeDisplay: recipe.totalTimeDisplay
        )
    }

    static func smallAccessibilityLabel(for recipe: WidgetSnapshot.Entry) -> String {
        if let totalTime = recipe.totalTimeDisplay {
            "Today's recipe: \(recipe.title). \(totalTime)."
        } else {
            "Today's recipe: \(recipe.title)."
        }
    }

    static func mediumAccessibilityLabel(for recipe: WidgetSnapshot.Entry) -> String {
        var parts = ["Today's recipe: \(recipe.title)"]
        if !recipe.excerpt.isEmpty { parts.append(recipe.excerpt) }
        if let totalTime = recipe.totalTimeDisplay { parts.append(totalTime) }
        return parts.joined(separator: ". ") + "."
    }
}
