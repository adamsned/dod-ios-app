import DODDomain
import Foundation
import Testing

@testable import DODApp

/// L1 coverage for ``ArticleLinkResolver`` — the exact-slug-then-follow-redirect
/// policy behind DUT-920 (renamed recipes whose old slug 301-redirects to a new
/// one used to fall back to the browser).
///
/// The resolver's three I/O edges (slug extraction, the REST slug lookup, and
/// the redirect follow) are injected as closures, so every branch runs in-process
/// with no network and no `AppDependencies`. The four cases pin the contract:
/// the happy path never touches the network beyond the exact lookup; a miss that
/// redirects to a renamed slug resolves (THE FIX); a miss whose redirect also
/// misses degrades to `nil`; and an unhelpful redirect (same slug / off-site /
/// none) degrades to `nil`.
@Suite("Article Link Resolver (DUT-920)")
struct ArticleLinkResolverTests {

    /// (a) An exact-slug hit returns the post and the redirect follow is
    /// **never** invoked — the happy path pays zero extra network cost.
    @Test func exactSlugHit_returnsItem_withoutFollowingRedirect() async {
        let spy = RedirectSpy()
        let slug = "dutch-oven-ham-and-bean-soup"
        let table = [slug: makeItem(id: 4478, slug: slug)]
        let resolved = await ArticleLinkResolver.resolve(
            url: makeURL("https://www.dutchovendaddy.com/\(slug)/"),
            slug: { AppDependencies.recipeSlug(fromDODURL: $0) },
            postLookup: { table[$0] },
            followRedirect: { redirectURL in
                await spy.record()
                return redirectURL
            }
        )
        #expect(resolved?.id == 4478)
        #expect(await spy.callCount == 0, "exact-slug hit must not follow the redirect")
    }

    /// (b) THE FIX: an exact-slug miss whose link 301-redirects to a *renamed*
    /// slug resolves via a retry on the resolved slug. Models the live DUT-920
    /// case: `dutch-oven-ham-and-bean-soup` (gone) →
    /// `dutch-oven-ham-and-bean-soup-tomato-based` (post 4478).
    @Test func exactMiss_redirectToRenamedSlug_returnsItem() async {
        let spy = RedirectSpy()
        let newSlug = "dutch-oven-ham-and-bean-soup-tomato-based"
        let table = [newSlug: makeItem(id: 4478, slug: newSlug)]
        let resolved = await ArticleLinkResolver.resolve(
            url: makeURL("https://www.dutchovendaddy.com/dutch-oven-ham-and-bean-soup/"),
            slug: { AppDependencies.recipeSlug(fromDODURL: $0) },
            postLookup: { table[$0] },
            followRedirect: { _ in
                await spy.record()
                return makeURL("https://www.dutchovendaddy.com/\(newSlug)/")
            }
        )
        #expect(resolved?.id == 4478, "renamed recipe must resolve via the redirected slug")
        #expect(await spy.callCount == 1, "an exact-slug miss must follow the redirect exactly once")
    }

    /// (c) An exact miss whose redirect lands on a *different* slug that also
    /// matches no post degrades to `nil` (browser fallback).
    @Test func exactMiss_redirectAlsoMisses_returnsNil() async {
        let table: [String: RecipeListItem] = [:]
        let resolved = await ArticleLinkResolver.resolve(
            url: makeURL("https://www.dutchovendaddy.com/renamed-old/"),
            slug: { AppDependencies.recipeSlug(fromDODURL: $0) },
            postLookup: { table[$0] },
            followRedirect: { _ in makeURL("https://www.dutchovendaddy.com/renamed-new-still-missing/") }
        )
        #expect(resolved == nil)
    }

    /// (d) An exact miss with an *unhelpful* redirect — the same slug, an
    /// off-site URL, or no redirect at all — degrades to `nil` in every case
    /// (and never retries a redundant lookup on an unchanged slug).
    @Test func exactMiss_unhelpfulRedirect_returnsNil() async {
        let table: [String: RecipeListItem] = [:]
        let originalURL = makeURL("https://www.dutchovendaddy.com/renamed-old/")

        // Redirect resolves to the SAME slug — no retry, no resolution.
        let sameSlug = await ArticleLinkResolver.resolve(
            url: originalURL,
            slug: { AppDependencies.recipeSlug(fromDODURL: $0) },
            postLookup: { table[$0] },
            followRedirect: { $0 }
        )
        #expect(sameSlug == nil, "an unchanged redirect slug must not resolve")

        // Redirect leaves dutchovendaddy.com — off-site slug is nil.
        let offSite = await ArticleLinkResolver.resolve(
            url: originalURL,
            slug: { AppDependencies.recipeSlug(fromDODURL: $0) },
            postLookup: { table[$0] },
            followRedirect: { _ in makeURL("https://example.com/renamed-new/") }
        )
        #expect(offSite == nil, "an off-site redirect must not resolve")

        // No redirect at all.
        let noRedirect = await ArticleLinkResolver.resolve(
            url: originalURL,
            slug: { AppDependencies.recipeSlug(fromDODURL: $0) },
            postLookup: { table[$0] },
            followRedirect: { _ in nil }
        )
        #expect(noRedirect == nil, "a failed redirect must not resolve")
    }
}

/// Sendable call counter for the redirect-follow closure, so the tests can
/// assert the happy path never follows a redirect while the fix path does.
private actor RedirectSpy {
    private(set) var callCount = 0
    func record() {
        callCount += 1
    }
}

/// Non-failing URL builder so the fixtures avoid force-unwrapping (swiftlint
/// `force_unwrapping`). The literals are static + well-formed, so the fallback
/// is never taken in practice.
private func makeURL(_ string: String) -> URL {
    URL(string: string) ?? URL(filePath: "/")
}

private func makeItem(id: Int, slug: String) -> RecipeListItem {
    RecipeListItem(
        id: id,
        title: "Recipe \(slug)",
        excerpt: "",
        publishedAt: .distantPast,
        canonicalURL: makeURL("https://www.dutchovendaddy.com/\(slug)/")
    )
}
