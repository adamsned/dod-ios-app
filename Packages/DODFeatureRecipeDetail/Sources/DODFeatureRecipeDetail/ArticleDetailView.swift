import DODDesignSystem
import DODDomain
import SwiftUI

/// Article-rendering screen for posts that lack parseable JSON-LD `@type: Recipe`
/// data — typically roundup posts like "Best Dutch Oven Recipes (30+ Tried and
/// Tested Favorites)" that the user wants to read in-app without the post
/// being hidden from lists per the pre-T-640 CL-9 contract.
///
/// **What `ArticleDetailView` shows (US-37 / AC-37.3):**
/// - Hero image (`RecipeDetailHero`, same primitive the recipe screen uses).
/// - Title + published date caption.
/// - Sanitized plain-text article body (extracted by
///   ``DODSupport/ArticleBodyExtractor`` from the rendered HTML page).
///
/// **What `ArticleDetailView` deliberately does NOT show (CL-63 decision 5):**
/// - Ingredients section (no `Recipe.ingredients` data on articles).
/// - Cook Mode CTA (US-7 needs `recipeInstructions` — articles have none).
/// - Servings stepper (US-31 needs `recipeYield` — articles have none).
/// - Rating summary + composer (US-13).
/// - Comments composer (US-14).
/// - Related-recipes strip (US-4 / AC-4.6 — articles are themselves often
///   related-recipes content; the strip would be visually redundant).
///
/// Save + Share affordances inherit from the parent `RecipeDetailView`'s
/// nav-bar toolbar (AC-4.7 + AC-4.8 preserved — any post is shareable and
/// saveable). The parent view's `.toolbar` modifier renders the buttons
/// regardless of the active `LoadState` branch.
///
/// Spec trace: US-37, CL-63, AC-37.3, AC-37.5, AC-37.6, CC-1 / CC-7 / CC-8.
struct ArticleDetailView: View {

    let recipe: Recipe

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DODSpacing.lg) {
                RecipeDetailHero(
                    url: recipe.heroImageLargeURL ?? recipe.heroImage,
                    title: recipe.title
                )

                VStack(alignment: .leading, spacing: DODSpacing.md) {
                    publishedDateCaption
                    bodyText
                }
                .padding(.horizontal, DODSpacing.md)
                .padding(.bottom, DODSpacing.xl)
            }
        }
        .background(DODColor.surface)
    }

    /// Small caption showing "Published <relative-date>" above the body.
    /// Helps the reader distinguish current advice from older content
    /// per CL-63 decision 5 (third bullet).
    private var publishedDateCaption: some View {
        Text("Published \(recipe.publishedAt, style: .relative) ago")
            .dodFont(DODType.caption)
            .foregroundStyle(DODColor.labelSecondary)
            .accessibilityLabel(
                "Published \(Self.accessibilityDateFormatter.string(from: recipe.publishedAt))"
            )
    }

    /// The sanitized article body. Plain text for v1 per CL-63 decision 4 —
    /// rich HTML rendering (preserve `<h2>` / `<ul>` / `<a href>` styling) is
    /// a v1.x follow-up. The text supports Dynamic Type up to AX5 per
    /// constitution §7 / CC-1.
    private var bodyText: some View {
        Text(recipe.articleBodyHTML ?? "")
            .dodFont(DODType.body)
            .foregroundStyle(DODColor.label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .accessibilityLabel("Article body")
    }

    /// Shared formatter for the VoiceOver fallback label (the `style: .relative`
    /// Text view doesn't expose a stable string for the accessibility layer).
    private static let accessibilityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
