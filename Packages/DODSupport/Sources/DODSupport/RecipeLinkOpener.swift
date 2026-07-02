import SwiftUI

/// DUT-246 — an awaitable in-app recipe-link opener, injected through the
/// environment by the app shell (`RootView`).
///
/// The tree-wide `openURL` override (DOD-ART-2) returns `.handled`
/// synchronously and resolves the link in a fire-and-forget task, which is
/// right for inline article links but wrong for flows that need to know when
/// (and whether) the navigation actually happened — the First Cookout sheet
/// used to `dismiss()` immediately after `openURL(...)`, tearing itself down
/// into a blank dead interval while the resolve was still in flight.
///
/// `open(_:)` returns only after resolution completes: `true` when the link
/// was routed to an in-app destination (safe to dismiss any covering sheet),
/// `false` when it couldn't be (the shell falls back to the browser and the
/// caller should stay put). `nil` in the environment means no shell wired an
/// opener (previews / unhosted tests) — callers fall back to plain `openURL`.
public struct RecipeLinkOpener {
    private let handler: @MainActor (URL) async -> Bool

    public init(open handler: @escaping @MainActor (URL) async -> Bool) {
        self.handler = handler
    }

    /// Resolve + route the link. Returns `true` when in-app navigation
    /// happened; `false` when it fell through to the browser.
    @MainActor
    public func open(_ url: URL) async -> Bool {
        await handler(url)
    }
}

extension EnvironmentValues {
    /// DUT-246 — see ``RecipeLinkOpener``. `nil` when no app shell wired one.
    @Entry public var recipeLinkOpener: RecipeLinkOpener?
}
