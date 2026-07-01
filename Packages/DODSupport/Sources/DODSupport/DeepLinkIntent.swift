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
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let idString = comps?.queryItems?.first(where: { $0.name == "id" })?.value
        let id = idString.flatMap(Int.init)

        switch (host, path) {
        case ("saved", _), (nil, "/saved"):
            return .openSaved
        case ("recipe", "/cook"):
            guard let id else { return nil }
            return .startCookMode(recipeID: id)
        case ("recipe", _):
            guard let id else { return nil }
            return .openRecipe(id: id)
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
