import DODDesignSystem
import DODDomain
import DODSupport
import SwiftUI

/// Article-rendering screen for posts that lack parseable JSON-LD `@type: Recipe`
/// data — typically roundup posts like "Best Dutch Oven Recipes (30+ Tried and
/// Tested Favorites)" that the user wants to read in-app without the post
/// being hidden from lists per the pre-T-640 CL-9 contract.
///
/// **What `ArticleDetailView` shows (US-37 / AC-37.3 + DOD-ART-1):**
/// - Hero image (`RecipeDetailHero`, same primitive the recipe screen uses).
/// - Title + published date caption.
/// - The article body rendered as **native blocks** — styled headings, photos
///   with captions, bulleted/numbered lists, and paragraphs with tappable
///   links + bold/italic — parsed from the stored body HTML by
///   ``DODSupport/ArticleHTMLParser``. This replaces the v1 plain-text wall
///   that collapsed a 30+ recipe round-up (44 photos / 90 links) into one
///   unreadable blob (CL-63 "plain text for v1" → DOD-ART-1 rich follow-up).
///
/// **Legacy / fallback path.** Articles cached before DOD-ART-1 stored stripped
/// plain text (no tags), and a malformed body parses to zero blocks; either
/// way the view falls back to a single plain-text `Text` so nothing renders
/// blank. The body re-fetches as HTML on the next online open.
///
/// **What `ArticleDetailView` deliberately does NOT show (CL-63 decision 5):**
/// Ingredients, Cook Mode CTA, servings stepper, ratings, comments, related
/// strip — articles carry none of the `Recipe` data those need. Save + Share
/// inherit from the parent `RecipeDetailView` toolbar (AC-4.7 + AC-4.8).
///
/// Spec trace: US-37, CL-63, AC-37.3, AC-37.5, AC-37.6, DOD-ART-1, CC-1.
struct ArticleDetailView: View {

    let recipe: Recipe

    /// Parsed once per view identity (synchronously in `init`) so the first
    /// frame is already rich — no plain-text-then-rich flash — and snapshot
    /// rendering is deterministic. An 87 KB round-up parses in single-digit
    /// milliseconds, so the one-time cost on article open is invisible.
    @State private var blocks: [ArticleBlock]

    init(recipe: Recipe) {
        self.recipe = recipe
        _blocks = State(initialValue: ArticleHTMLParser.parse(html: recipe.articleBodyHTML ?? ""))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DODSpacing.lg) {
                RecipeDetailHero(
                    url: recipe.heroImageLargeURL ?? recipe.heroImage,
                    title: recipe.title
                )

                VStack(alignment: .leading, spacing: DODSpacing.md) {
                    publishedDateCaption
                    articleBody
                }
                .padding(.horizontal, DODSpacing.md)
                .padding(.bottom, DODSpacing.xl)
            }
        }
        .background(DODColor.surface)
    }

    /// Small caption showing "Published <relative-date>" above the body.
    private var publishedDateCaption: some View {
        Text("Published \(recipe.publishedAt, style: .relative) ago")
            .dodFont(DODType.caption)
            .foregroundStyle(DODColor.labelSecondary)
            .accessibilityLabel(
                "Published \(Self.accessibilityDateFormatter.string(from: recipe.publishedAt))"
            )
    }

    /// The rendered article body: native blocks when the HTML parsed, else a
    /// single plain-text fallback (legacy cache / unparseable body).
    @ViewBuilder
    private var articleBody: some View {
        if blocks.isEmpty {
            // Parser found no blocks — a legacy plain-text cache row, or an
            // article whose body uses only shapes the block scan doesn't emit
            // (a bare <table>, an <iframe> embed, etc.). `articleBodyHTML` now
            // holds raw HTML, so strip it to readable text rather than dumping
            // literal `<table>`/`<p>` tags on screen. No accessibilityLabel
            // override here — the Text content IS the body, so VoiceOver should
            // read it, not a generic "Article body". (review DOD-ART-1)
            let fallback = HTMLSanitizer.plainText(from: recipe.articleBodyHTML ?? "")
            if !fallback.isEmpty {
                Text(fallback)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        } else {
            VStack(alignment: .leading, spacing: DODSpacing.md) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
            .tint(DODColor.accent)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Article body")
        }
    }

    /// Render one parsed ``ArticleBlock`` as a native view.
    @ViewBuilder
    private func blockView(_ block: ArticleBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .dodFont(level <= 2 ? DODType.displayMedium : DODType.heading)
                .foregroundStyle(DODColor.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DODSpacing.sm)

        case .paragraph(let text):
            Text(text)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

        case .image(let url, let caption):
            articleImage(url: url, caption: caption)

        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: DODSpacing.sm) {
                        Text(ordered ? "\(index + 1)." : "•")
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.labelSecondary)
                        Text(item)
                            .dodFont(DODType.body)
                            .foregroundStyle(DODColor.label)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    /// A full-width article photo with an optional caption. Mirrors
    /// `RecipeDetailHero`'s `AsyncImage` phase handling; an unloaded /failed
    /// image shows a neutral placeholder rather than collapsing the layout.
    private func articleImage(url: URL, caption: String?) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    placeholder
                case .empty:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
            // Cap height so a tall vertical infographic / Pinterest pin
            // (e.g. 1200×4000) can't render many screens tall; scaledToFit
            // keeps the aspect ratio within the bound. (review DOD-ART-1)
            .frame(maxWidth: .infinity, maxHeight: Self.imageMaxHeight)
            .clipShape(RoundedRectangle(cornerRadius: DODSpacing.sm))
            .accessibilityLabel(caption ?? "Article image")

            if let caption, !caption.isEmpty {
                Text(caption)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: DODSpacing.sm)
            .fill(DODColor.surfaceElevated)
            .aspectRatio(3.0 / 2.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
    }

    /// Max on-screen height for an inline article photo (review DOD-ART-1).
    private static let imageMaxHeight: CGFloat = 480

    /// Shared formatter for the VoiceOver fallback label (the `style: .relative`
    /// Text view doesn't expose a stable string for the accessibility layer).
    private static let accessibilityDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
