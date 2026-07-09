import Foundation

/// Deep-link payload parsed from a `dod://` URL.
///
/// Spec trace: US-10 / AC-10.2. The App Intents and Spotlight surfaces
/// generate `dod://recipe?id=<int>`, `dod://recipe/cook?id=<int>`, and
/// `dod://saved`; the app routes each into the right tab + NavigationStack
/// path. URL routing is parser-only — the host app does the actual tab
/// switch and push.
///
/// Lives in DODSupport so the parser is unit-testable from a Swift Testing
/// target without dragging in the app target.
public enum DeepLinkIntent: Equatable, Sendable {
    case openRecipe(id: Int)
    case startCookMode(recipeID: Int)
    case openSaved

    /// Pure function for unit testing. Returns nil for any URL that isn't
    /// a recognized `dod://` action so the caller can ignore it without
    /// touching navigation state.
    public static func parse(_ url: URL) -> DeepLinkIntent? {
        // DUT-428: case-insensitive scheme, matching WidgetDeepLinkParser — iOS does
        // not normalize scheme case, so an uppercase "DOD://" would otherwise dead-end.
        guard url.scheme?.lowercased() == "dod" else { return nil }
        // URL.host is the action verb. Empty host (e.g. "dod:///saved")
        // falls through to the path-only branch below.
        let host = url.host?.lowercased()
        let path = url.path.lowercased()
        // Path with leading/trailing slashes stripped — a bare host route
        // (`dod://saved`, `dod://saved/`) normalizes to "".
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let idString = comps?.queryItems?.first(where: { $0.name == "id" })?.value
        let id = idString.flatMap(Int.init)

        // DUT-603 — constrain `saved` to the bare host (empty path) or the
        // path-only `dod:///saved` form, matching WidgetDeepLinkParser's
        // `isBare` gate. A path-bearing variant (`dod://saved/123`) is
        // malformed and must not route.
        if host == "saved" {
            return trimmedPath.isEmpty ? .openSaved : nil
        }

        switch (host, path) {
        case (nil, "/saved"):
            return .openSaved
        case ("recipe", "/cook"):
            // DUT — reject non-positive ids, mirroring the `("recipe", _)`
            // branch. `?id=0` / `?id=-5` would otherwise route to a cook mode
            // that fetches post 0 and dead-ends in a "Couldn't open that
            // recipe" toast.
            guard let id, id > 0 else { return nil }
            return .startCookMode(recipeID: id)
        case ("recipe", _):
            // DUT-603 — mirror the `article` branch: the id may ride the
            // trailing path component (`dod://recipe/123`) instead of a
            // `?id=` query. Fall back to the trimmed path so both grammars
            // parse, then reject non-positive ids.
            let recipeID = id ?? Int(trimmedPath)
            guard let recipeID, recipeID > 0 else { return nil }
            return .openRecipe(id: recipeID)
        case ("article", _):
            // DUT-566 — `dod://article/<id>` (the notification grammar for
            // `.article` posts) resolves by post id through the same
            // open-by-id route as a recipe: `PostKind` lives on the `Recipe`
            // domain type, so the detail view classifies recipe-vs-article
            // once the post is resolved. The id rides the path (`/<id>`), so
            // fall back to the trailing path component when no `?id=` query is
            // present, matching `WidgetDeepLinkParser`'s article grammar.
            let articleID = id ?? Int(trimmedPath)
            guard let articleID, articleID > 0 else { return nil }
            return .openRecipe(id: articleID)
        default:
            return nil
        }
    }

    /// Inverse of `parse(_:)`. Used by App Intents to build URLs that
    /// SwiftUI's `onOpenURL` then re-parses. Round-trips with `parse`.
    /// Falls back to `dod://` (which the parser rejects) on the impossible
    /// case where URL construction fails — we never want to crash here.
    public var url: URL {
        let raw: String
        switch self {
        case .openRecipe(let id):
            raw = "dod://recipe?id=\(id)"
        case .startCookMode(let recipeID):
            raw = "dod://recipe/cook?id=\(recipeID)"
        case .openSaved:
            raw = "dod://saved"
        }
        return URL(string: raw) ?? URL(filePath: "/")
    }
}
