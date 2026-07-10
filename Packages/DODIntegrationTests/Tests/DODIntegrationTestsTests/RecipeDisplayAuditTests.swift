import DODDomain
import DODNetworking
import DODSupport
import Foundation
import Testing

/// DUT-917 — live catalog display audit. Walks EVERY published post on
/// dutchovendaddy.com and flags recipe/article content that would render
/// badly in the app: missing structured recipe fields, duplicated body
/// images, and internal-only captions (e.g. "photo for social media") that
/// were never meant to reach a reader.
///
/// Slow and network-dependent — same L2 tier + `DOD_RUN_LIVE_TESTS=1` gate as
/// ``LiveAPITests`` so PR builds skip it and only the nightly job runs it.
/// The body-block audit mirrors the app's real render path: each post is
/// classified recipe-vs-article exactly like
/// ``RecipeDetailViewModel`` (`+Classify`) does, then the same
/// ``ArticleBodyExtractor`` + ``ArticleHTMLParser`` pipeline produces the
/// blocks the user actually sees — so a finding here is a finding on screen.
@Suite(
    "Recipe display audit (L2 — live)",
    .enabled(if: ProcessInfo.processInfo.environment["DOD_RUN_LIVE_TESTS"] == "1")
)
struct RecipeDisplayAuditTests {

    /// Cap on in-flight page fetches. The catalog is a few hundred posts; a
    /// small window keeps the audit from hammering the origin (and Cloudflare)
    /// while still finishing in a couple of minutes.
    private static let maxInFlight = 6

    /// WP REST caps `per_page` at 100 — the widest single page we can pull.
    private static let pageSize = 100

    @Test func everyPublishedPostRendersWithoutDisplayProblems() async throws {
        let posts = try await Self.allPosts()
        try #require(!posts.isEmpty, "Live API returned zero posts — nothing to audit")

        let findings = await Self.auditAll(posts)

        for line in findings.sorted() {
            print(line)
        }
        print(
            "📋 Recipe display audit — \(posts.count) posts audited, "
                + "\(findings.count) display problem(s) found"
        )

        #expect(findings.isEmpty, "Found \(findings.count) display problems — see log")
    }

    // MARK: - Catalog enumeration

    /// Page through the full posts endpoint (100 at a time) using the real
    /// `X-WP-TotalPages` count so no post is missed off the tail.
    private static func allPosts() async throws -> [RecipeListItem] {
        let client = WPRestClient()
        let firstPage = try await client.postsPage(page: 1, perPage: pageSize)
        var all = firstPage.items
        guard firstPage.totalPages > 1 else { return all }
        for page in 2...firstPage.totalPages {
            let next = try await client.postsPage(page: page, perPage: pageSize)
            all.append(contentsOf: next.items)
        }
        return all
    }

    // MARK: - Bounded-concurrency fan-out

    /// Audit every post with at most ``maxInFlight`` page fetches running at
    /// once: seed the window, then top it up as each result lands.
    private static func auditAll(_ posts: [RecipeListItem]) async -> [String] {
        await withTaskGroup(of: [String].self) { group in
            var findings: [String] = []
            var nextIndex = 0
            let window = min(maxInFlight, posts.count)
            while nextIndex < window {
                let post = posts[nextIndex]
                group.addTask { await audit(post) }
                nextIndex += 1
            }
            while let result = await group.next() {
                findings.append(contentsOf: result)
                if nextIndex < posts.count {
                    let post = posts[nextIndex]
                    group.addTask { await audit(post) }
                    nextIndex += 1
                }
            }
            return findings
        }
    }

    // MARK: - Per-post audit

    /// Fetch + audit a single post, catching per-post so one bad page can't
    /// abort the whole run.
    private static func audit(_ post: RecipeListItem) async -> [String] {
        guard let url = post.canonicalURL else {
            return [format(post.title, "missing canonical URL", nil)]
        }
        let html: String
        do {
            html = try await RecipePageFetcher().html(for: url)
        } catch {
            return [format(post.title, "fetch failed: \(error)", url)]
        }
        var findings = recipeCompletenessFindings(html: html, post: post, url: url)
        findings.append(contentsOf: bodyDisplayFindings(html: html, post: post, url: url))
        return findings
    }

    // MARK: - Recipe completeness (check B)

    /// Structured-recipe checks. Only runs when the post classifies as a
    /// recipe (same gate the app uses in `classifyPage`); pure articles have
    /// no ingredients/instructions and are audited by the body checks only.
    private static func recipeCompletenessFindings(
        html: String,
        post: RecipeListItem,
        url: URL
    ) -> [String] {
        guard let recipe = try? JSONLDRecipeParser.parse(html: html, merging: post, canonicalURL: url),
            !recipe.instructions.isEmpty || JSONLDRecipeParser.hasRecipeJSONLD(html: html)
        else {
            return []
        }
        var findings: [String] = []
        if isBlank(recipe.title) {
            findings.append(format(post.title, "blank recipe title", url))
        }
        if recipe.ingredients.isEmpty {
            findings.append(format(post.title, "recipe has no ingredients", url))
        } else if recipe.ingredients.contains(where: { isBlank($0.text) }) {
            findings.append(format(post.title, "blank ingredient text", url))
        }
        if recipe.instructions.isEmpty {
            findings.append(format(post.title, "recipe has no instructions", url))
        } else if recipe.instructions.contains(where: { isBlank($0.text) }) {
            findings.append(format(post.title, "blank instruction text", url))
        }
        return findings
    }

    // MARK: - Body / article display (check C)

    /// Run the duplicate-image and internal-caption checks over the exact
    /// blocks the app would render for this post.
    private static func bodyDisplayFindings(
        html: String,
        post: RecipeListItem,
        url: URL
    ) -> [String] {
        var findings: [String] = []
        var previousImageURL: URL?
        for block in renderedBlocks(html: html, post: post, url: url) {
            guard case .image(let imageURL, let caption) = block else {
                previousImageURL = nil
                continue
            }
            if let previousImageURL, previousImageURL == imageURL {
                findings.append(format(post.title, "duplicate consecutive image: \(imageURL)", url))
            }
            previousImageURL = imageURL
            if let caption, isInternalCaption(caption) {
                findings.append(format(post.title, "internal-looking caption: \"\(caption)\"", url))
            }
        }
        return findings
    }

    /// Reproduce `RecipeDetailViewModel.classifyPage`'s body-block selection:
    /// a recipe post renders the pre-card blurb (`extractRecipeBlurb`), an
    /// article renders the full body (`extractContentHTML`); both go through
    /// `ArticleHTMLParser.parse` with the page URL as the image base.
    private static func renderedBlocks(
        html: String,
        post: RecipeListItem,
        url: URL
    ) -> [ArticleBlock] {
        let isRecipeSubject = JSONLDRecipeParser.hasRecipeJSONLD(html: html)
        let parsed = try? JSONLDRecipeParser.parse(html: html, merging: post, canonicalURL: url)
        let bodyHTML: String
        if let parsed, !parsed.instructions.isEmpty || isRecipeSubject {
            bodyHTML = ArticleBodyExtractor.extractRecipeBlurb(html: html, paragraphLimit: .max)
        } else {
            bodyHTML = ArticleBodyExtractor.extractContentHTML(html: html)
        }
        return bodyHTML.isEmpty ? [] : ArticleHTMLParser.parse(html: bodyHTML, baseURL: url)
    }

    // MARK: - Caption heuristics

    /// Substrings/patterns that only ever appear in captions authored for
    /// internal use (SEO, social scheduling, editorial placeholders) and
    /// should never render to a reader.
    private static let internalCaptionLiterals = [
        "photo for social media",
        "for social media",
        "featured image",
        "do not use",
        "placeholder",
        "alt text",
    ]

    private static func isInternalCaption(_ caption: String) -> Bool {
        let lowered = caption.lowercased()
        if internalCaptionLiterals.contains(where: { lowered.contains($0) }) {
            return true
        }
        return lowered.range(of: #"image \d+"#, options: .regularExpression) != nil
    }

    // MARK: - Formatting helpers

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func format(_ title: String, _ problem: String, _ url: URL?) -> String {
        let suffix = url.map { " (\($0.absoluteString))" } ?? ""
        return "⚠️ \(title) — \(problem)\(suffix)"
    }
}
