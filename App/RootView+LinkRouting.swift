import DODSupport
import SwiftUI

// MARK: - DOD-ART-2 / DUT-243 / DUT-246 in-app article-link routing
//
// Extracted from `RootView.swift` so that file stays under the SwiftLint
// `file_length` cap. The referenced `@State` sinks are `internal` on
// `RootView` for exactly this cross-file access.

extension RootView {

    /// The external-route sink for one tab. Feed/Saved/Search each own a
    /// sink so both layouts (phone tabs + iPad split detail) can hand every
    /// `TabStack` its own; Settings renders no article surface, so it keeps
    /// the inert constant.
    func externalRouteBinding(for tab: AppTab) -> Binding<ExternalRoute?> {
        switch tab {
        case .feed: return $feedExternalRoute
        case .saved: return $savedExternalRoute
        case .search: return $searchExternalRoute
        case .settings: return .constant(nil)
        }
    }

    /// Custom `openURL` handler for in-app article recipe links. A
    /// `dutchovendaddy.com` recipe link is resolved to its post and pushed
    /// into the CURRENT tab's stack (DUT-243 — reading a round-up in Saved
    /// and tapping an inline link no longer yanks the user to Feed); a
    /// non-recipe `dutchovendaddy.com` URL or any off-site URL opens in the
    /// browser. Returns synchronously — the resolve is a fire-and-forget
    /// Task; flows that need the outcome use ``openRecipeLink(_:)`` via the
    /// `recipeLinkOpener` environment (DUT-246).
    func handleArticleLinkTap(_ url: URL) -> OpenURLAction.Result {
        guard AppDependencies.recipeSlug(fromDODURL: url) != nil else {
            return .systemAction
        }
        Task { @MainActor in _ = await openRecipeLink(url) }
        return .handled
    }

    /// DUT-246 — the awaitable core of the article-link routing. Resolves the
    /// link and routes it into the currently-selected tab's stack, returning
    /// `true` once in-app navigation actually happened. A URL that isn't a
    /// resolvable recipe (offline; or a slug that maps to a WP page, like the
    /// campfire heat-and-coals guide) falls back to the system browser and
    /// returns `false` so a covering sheet knows to stay put.
    func openRecipeLink(_ url: URL) async -> Bool {
        guard AppDependencies.recipeSlug(fromDODURL: url) != nil else {
            systemOpenURL(url)
            return false
        }
        guard let item = await dependencies.resolveRecipe(forArticleLink: url) else {
            systemOpenURL(url)
            return false
        }
        routeIntoCurrentTab(.recipe(item: item, autoStartCookMode: false))
        return true
    }

    /// DUT-243 — push a route onto the CURRENTLY-SELECTED tab's stack
    /// (mirroring `onSelectRelated`, which appends in place) instead of
    /// hard-coding a switch to Feed. The forced `.feed` switch remains only
    /// for genuine external entry points (Spotlight / App Intents /
    /// notifications — see `handle(intent:)`) and for Settings, which has no
    /// article surface of its own.
    private func routeIntoCurrentTab(_ route: RecipeRoute) {
        switch selectedTab {
        case .feed: feedExternalRoute = .push(route)
        case .saved: savedExternalRoute = .push(route)
        case .search: searchExternalRoute = .push(route)
        case .settings:
            selectedTab = .feed
            feedExternalRoute = .push(route)
        }
    }
}
