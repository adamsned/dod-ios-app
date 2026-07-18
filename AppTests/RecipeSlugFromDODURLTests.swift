import Foundation
import Testing

@testable import DODApp

/// Direct adversarial URL-parsing coverage for
/// ``AppDependencies.recipeSlug(fromDODURL:)`` (DUT-920) — the pure
/// `dutchovendaddy.com` permalink → slug extraction helper one level below
/// ``ArticleLinkResolver``, whose own redirect-follow/retry policy is already
/// covered by `ArticleLinkResolverTests` but which never itself received
/// direct test coverage. Every case here was verified empirically against
/// Foundation's real `URL`/`pathComponents` behavior before being pinned.
@Suite("Recipe Slug Extraction Tests (DUT-920)")
struct RecipeSlugFromDODURLTests {

    @Test func bareHostNoPath_returnsNil() {
        let url = makeURL("https://dutchovendaddy.com")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(slug == nil, "a bare host with no path should return nil")
    }

    @Test func bareHostRootSlash_returnsNil() {
        let url = makeURL("https://dutchovendaddy.com/")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(slug == nil, "a bare host with a root slash should return nil")
    }

    @Test func slugWithQueryString_ignoresQuery_returnsSlug() {
        let url = makeURL("https://dutchovendaddy.com/my-recipe/?utm_source=x")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(slug == "my-recipe", "a URL with a query string should ignore the query and return the slug")
    }

    @Test func slugWithFragment_ignoresFragment_returnsSlug() {
        let url = makeURL("https://dutchovendaddy.com/my-recipe#comments")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(slug == "my-recipe", "a URL with a fragment should ignore the fragment and return the slug")
    }

    @Test func slugWithQueryAndFragment_ignoresBoth_returnsSlug() {
        let url = makeURL("https://dutchovendaddy.com/my-recipe/?a=1#frag")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(slug == "my-recipe", "a URL with both query and fragment should ignore both and return the slug")
    }

    @Test func uppercaseSchemeAndHost_isCaseInsensitive_returnsSlug() {
        let url = makeURL("HTTPS://WWW.DUTCHOVENDADDY.COM/recipe/")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(slug == "recipe", "an uppercase scheme and host should be case insensitive and return the slug")
    }

    @Test func mixedCaseHostOnly_isCaseInsensitive_returnsSlug() {
        let url = makeURL("https://Dutchovendaddy.Com/recipe/")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(slug == "recipe", "a mixed case host should be case insensitive and return the slug")
    }

    /// Exact-equality host check, not substring/suffix matching — a suffix-only
    /// check here would let `evil.dutchovendaddy.com` masquerade as trusted
    /// (open-redirect-adjacent trust bug class).
    @Test func subdomainOfRealHost_isNotTrusted_returnsNil() {
        let url = makeURL("https://evil.dutchovendaddy.com/recipe/")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(slug == nil, "a subdomain of the real host must not be trusted")
    }

    /// Same exact-equality guard from the other direction: the real host as a
    /// *prefix* of an attacker-controlled host must not be trusted either.
    @Test func hostWithRealDomainAsPrefix_isNotTrusted_returnsNil() {
        let url = makeURL("https://dutchovendaddy.com.evil.com/recipe/")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(slug == nil, "a host with the real domain as a prefix must not be trusted")
    }

    @Test func similarButWrongHost_isNotTrusted_returnsNil() {
        let url = makeURL("https://notdutchovendaddy.com/recipe/")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(slug == nil, "a host that is similar but wrong must not be trusted")
    }

    /// Pins current "first segment wins" behavior. Not reachable as a bug in
    /// production today — live dutchovendaddy.com WordPress permalinks are
    /// confirmed flat (`/wp-json/wp/v2/posts?_fields=link` returns only
    /// `/<slug>/`, never a category-prefixed path) — but pinned in case that
    /// ever changes.
    @Test func multiSegmentPath_returnsFirstSegmentOnly() {
        let url = makeURL("https://dutchovendaddy.com/category/some-recipe/")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(slug == "category", "a URL with a multi-segment path should return the first segment only")
    }

    @Test func percentEncodedEmDash_isDecoded_returnsDecodedSlug() {
        let url = makeURL("https://dutchovendaddy.com/dutch-oven-pot-au-feu%E2%80%94classic/")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(
            slug == "dutch-oven-pot-au-feu—classic",
            "a URL with a percent-encoded em-dash should decode it and return the slug"
        )
    }

    @Test func percentEncodedAccentedCharacter_isDecoded_returnsDecodedSlug() {
        let url = makeURL("https://dutchovendaddy.com/caf%C3%A9-recipe/")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(
            slug == "café-recipe",
            "a URL with a percent-encoded accented character should decode it and return the slug"
        )
    }

    @Test func apexHost_returnsSlug() {
        let url = makeURL("https://dutchovendaddy.com/some-recipe/")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(slug == "some-recipe", "a URL with the apex host should return the slug")
    }

    @Test func wwwHost_returnsSlug() {
        let url = makeURL("https://www.dutchovendaddy.com/some-recipe/")
        let slug = AppDependencies.recipeSlug(fromDODURL: url)
        #expect(slug == "some-recipe", "a URL with the www host should return the slug")
    }
}

/// Non-failing URL builder so the fixtures avoid force-unwrapping (swiftlint
/// `force_unwrapping`). The literals are static + well-formed, so the fallback
/// is never taken in practice.
private func makeURL(_ string: String) -> URL {
    URL(string: string) ?? URL(filePath: "/")
}
