import DODDomain
import DODSupport
import Foundation

/// App-side type alias for the deep link route parsed in DODSupport. The
/// parser lives in DODSupport (so it gets covered by the package test
/// suite); the app keeps a thin wrapper that can grow app-only behaviour
/// without leaking it into the shared module.
///
/// Spec trace: US-9 AC-9.2.
typealias WidgetDeepLink = WidgetDeepLinkParser.Route

extension WidgetDeepLink {

    /// Convenience initializer mirroring the previous app-local API.
    init?(url: URL) {
        guard let parsed = WidgetDeepLinkParser.parse(url) else { return nil }
        self = parsed
    }
}

/// Build a `RecipeListItem` from a widget snapshot entry. Used to seed the
/// navigation push when the deep link comes from the widget — the snapshot
/// has the same fields the feed cell would have, so the detail screen can
/// open instantly with title/hero/excerpt while the JSON-LD parse continues
/// in the background.
extension RecipeListItem {

    init(snapshot: WidgetSnapshot.Entry) {
        self.init(
            id: snapshot.id,
            title: snapshot.title,
            excerpt: snapshot.excerpt,
            heroImage: snapshot.heroImageURL,
            publishedAt: snapshot.publishedAt,
            totalTimeDisplay: snapshot.totalTimeDisplay,
            canonicalURL: snapshot.canonicalURL
        )
    }
}
