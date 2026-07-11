import DODDomain
import DODNetworking
import DODSupport
import Foundation
import Testing

/// DUT-920 — live catalog link audit. Crawls EVERY published post on
/// dutchovendaddy.com, extracts the in-article recipe links from each body, and
/// flags any link that would fall back to the system browser when tapped in the
/// app (i.e. that the production `AppDependencies.resolveRecipe(forArticleLink:)`
/// path could not resolve to a post).
///
/// Mirrors the shipped fix exactly: each link is tried as an exact-slug REST
/// lookup first, and on a miss the link's redirect is followed (a renamed recipe
/// 301-redirects its old slug to the new one) and retried with the resolved slug.
/// A link that resolves on neither attempt is a real in-app dead link.
///
/// Slow and network-dependent — same L2 tier + `DOD_RUN_LIVE_TESTS=1` gate as
/// ``LiveAPITests`` so PR builds skip it and only the nightly job runs it.
@Suite(
    "Recipe Link Audit",
    .enabled(if: ProcessInfo.processInfo.environment["DOD_RUN_LIVE_TESTS"] == "1")
)
struct RecipeLinkAuditTests {

    /// Cap on in-flight per-post fetches — keeps the audit from hammering the
    /// origin (and Cloudflare) while still finishing in a couple of minutes.
    private static let maxInFlight = 5

    /// WP REST caps `per_page` at 100 — the widest single page we can pull.
    private static let pageSize = 100

    @Test func everyInAppRecipeLinkResolvesWithoutBrowserFallback() async throws {
        let client = WPRestClient()
        let posts = try await Self.allPosts(client: client)
        try #require(!posts.isEmpty, "Live API returned zero posts — nothing to audit")

        // Non-recipe routes that share the flat `/<slug>/` permalink shape but
        // are SUPPOSED to fall back to the browser (category/tag archives, WP
        // pages like `/about-me/`, and the WPRM `/wprm_print/…` print route).
        // Excluding them keeps a finding meaning a genuine dead RECIPE link.
        let excluded = await Self.nonRecipeSlugs(client: client)

        let result = await Self.auditAll(posts, excluding: excluded, client: client)

        for line in result.findings.sorted() {
            print("BROKEN: \(line)")
        }
        print(
            "📋 Recipe link audit — \(posts.count) posts checked, "
                + "\(result.linksChecked) in-app recipe links checked, "
                + "\(result.findings.count) broken"
        )

        #expect(
            result.findings.isEmpty,
            "Found \(result.findings.count) broken in-app recipe links — see log"
        )
    }

    // MARK: - Catalog enumeration

    /// Page through the full posts endpoint (100 at a time) using the real
    /// `X-WP-TotalPages` count so no post is missed off the tail.
    private static func allPosts(client: WPRestClient) async throws -> [RecipeListItem] {
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

    /// Audit every post with at most ``maxInFlight`` per-post fetches running at
    /// once: seed the window, then top it up as each result lands.
    private static func auditAll(
        _ posts: [RecipeListItem],
        excluding excluded: Set<String>,
        client: WPRestClient
    ) async -> (linksChecked: Int, findings: [String]) {
        await withTaskGroup(of: (Int, [String]).self) { group in
            var findings: [String] = []
            var linksChecked = 0
            var nextIndex = 0
            let window = min(maxInFlight, posts.count)
            while nextIndex < window {
                let post = posts[nextIndex]
                group.addTask { await audit(post, excluding: excluded, client: client) }
                nextIndex += 1
            }
            while let result = await group.next() {
                linksChecked += result.0
                findings.append(contentsOf: result.1)
                if nextIndex < posts.count {
                    let post = posts[nextIndex]
                    group.addTask { await audit(post, excluding: excluded, client: client) }
                    nextIndex += 1
                }
            }
            return (linksChecked, findings)
        }
    }

    // MARK: - Per-post audit

    /// Fetch a post's page, pull its in-article recipe links, and resolve each
    /// through the same exact-slug-then-redirect policy the app ships. Returns
    /// the count of links checked and any dead-link findings.
    private static func audit(
        _ post: RecipeListItem,
        excluding excluded: Set<String>,
        client: WPRestClient
    ) async -> (Int, [String]) {
        guard let url = post.canonicalURL else { return (0, []) }
        guard let html = try? await RecipePageFetcher().html(for: url) else { return (0, []) }
        let links = recipeLinks(inBodyOf: html, base: url, excluding: excluded)
        var findings: [String] = []
        for link in links {
            guard let slug = recipeSlug(from: link) else { continue }
            let resolved = await resolvesInApp(link: link, slug: slug, client: client)
            if !resolved {
                findings.append("\(post.title) → \(link.absoluteString)")
            }
        }
        return (links.count, findings)
    }

    /// The production resolution policy (see `ArticleLinkResolver`): exact-slug
    /// lookup first, then follow the redirect and retry with the resolved slug.
    private static func resolvesInApp(
        link: URL,
        slug: String,
        client: WPRestClient
    ) async -> Bool {
        if (try? await client.post(slug: slug)) != nil {
            return true
        }
        guard
            let finalURL = await followRedirect(link),
            let resolvedSlug = recipeSlug(from: finalURL),
            resolvedSlug != slug
        else {
            return false
        }
        return (try? await client.post(slug: resolvedSlug)) != nil
    }

    // MARK: - Link extraction

    /// Extract the distinct DOD recipe permalinks from a post's **article body**
    /// (the `entry-content` slice), excluding nav/footer/sidebar chrome. Keeps
    /// only flat `/<slug>/` DOD links whose slug is a recipe candidate — i.e.
    /// not a category/tag/page/print route in `excluded`.
    private static func recipeLinks(
        inBodyOf html: String,
        base: URL,
        excluding excluded: Set<String>
    ) -> [URL] {
        let body = ArticleBodyExtractor.extractContentHTML(html: html)
        guard !body.isEmpty, let regex = try? NSRegularExpression(pattern: #"href="([^"]+)""#) else {
            return []
        }
        let range = NSRange(body.startIndex..., in: body)
        var urls: [URL] = []
        var seen: Set<String> = []
        regex.enumerateMatches(in: body, range: range) { match, _, _ in
            guard
                let match,
                let captured = Range(match.range(at: 1), in: body),
                let url = URL(string: String(body[captured]), relativeTo: base)?.absoluteURL
            else {
                return
            }
            if seen.insert(url.absoluteString).inserted {
                urls.append(url)
            }
        }
        return urls.filter { url in
            guard let slug = recipeSlug(from: url) else { return false }
            return !excluded.contains(slug)
        }
    }

    // MARK: - Non-recipe route exclusions

    /// Slugs that share the flat `/<slug>/` permalink shape but are not recipe
    /// posts: every category + tag archive slug (fetched live), every WP page
    /// slug (e.g. `about-me`), and the WPRM `/wprm_print/…` print route. A link
    /// to any of these correctly opens in the browser, so it is not a finding.
    private static func nonRecipeSlugs(client: WPRestClient) async -> Set<String> {
        var slugs: Set<String> = ["wprm_print"]
        if let categories = try? await client.categories() {
            slugs.formUnion(categories.map(\.slug))
        }
        slugs.formUnion(await fetchSlugs(taxonomy: "tags"))
        slugs.formUnion(await fetchSlugs(taxonomy: "pages"))
        return slugs
    }

    /// Page a slug-only WP REST collection (`tags`, `pages`) into a slug set.
    /// `WPRestClient` has no typed accessor for these, so this hits the endpoint
    /// directly — the audit only needs the slug strings.
    private static func fetchSlugs(taxonomy: String) async -> Set<String> {
        var result: Set<String> = []
        var page = 1
        let maxPages = 10
        while page <= maxPages {
            let query = "?per_page=100&page=\(page)&_fields=slug"
            guard
                let url = URL(string: "\(baseURLString)\(taxonomy)\(query)"),
                let (data, response) = try? await URLSession.shared.data(from: url),
                let http = response as? HTTPURLResponse,
                http.statusCode == 200,
                let rows = try? JSONDecoder().decode([SlugRow].self, from: data),
                !rows.isEmpty
            else {
                break
            }
            result.formUnion(rows.map(\.slug))
            if rows.count < 100 { break }
            page += 1
        }
        return result
    }

    private static let baseURLString = "https://www.dutchovendaddy.com/wp-json/wp/v2/"

    private struct SlugRow: Decodable {
        let slug: String
    }

    /// Local mirror of `AppDependencies.recipeSlug(fromDODURL:)` (that type lives
    /// in the App target, unreachable from this package): the first non-empty
    /// path component of a `(www.)dutchovendaddy.com` URL, else `nil`.
    private static func recipeSlug(from url: URL) -> String? {
        guard
            let host = url.host()?.lowercased(),
            host == "dutchovendaddy.com" || host == "www.dutchovendaddy.com"
        else {
            return nil
        }
        return url.pathComponents.first { $0 != "/" && !$0.isEmpty }
    }

    /// Follow a URL's redirect chain (URLSession follows 301s by default) and
    /// return the final URL, or `nil` on failure.
    private static func followRedirect(_ url: URL) async -> URL? {
        guard let (_, response) = try? await URLSession.shared.data(from: url) else { return nil }
        return response.url
    }
}
