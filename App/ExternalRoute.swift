import Foundation

/// How an externally-driven route enters a tab's `NavigationStack` (DUT-243).
///
/// Deep links and in-app link taps want different stack semantics, so the
/// route sink carries the intent instead of `TabStack` guessing:
/// - `replaceStack` — Spotlight / App Intents / widget / notification entry
///   points. The user arrived from outside the app, so Back should land on
///   the tab root (DUT-310).
/// - `push` — an in-app article-link tap (DUT-243). The user is mid-flow
///   (reading an article), so Back must return to where they were.
enum ExternalRoute: Hashable {
    case replaceStack(RecipeRoute)
    case push(RecipeRoute)
}
