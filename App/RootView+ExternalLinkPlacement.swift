import Foundation

// DUT-2447 — where a resolved recipe link lands. Kept in its own file so
// `RootView+LinkRouting.swift` stays under the SwiftLint `file_length` cap.
extension RootView {

    /// The tab + queue entry for a resolved recipe link.
    struct LinkPlacement: Equatable {
        let tab: AppTab
        let route: ExternalRoute
    }

    /// An in-app tap (`external == false`) pushes onto the tab it was tapped
    /// from (DUT-243 / DUT-462). An external entry point (Universal Link opened
    /// from Safari/Messages) switches to Feed and replaces its stack so Back
    /// lands on the Feed root, matching `dod://`, widget and Spotlight links.
    /// Pure + `nonisolated` so plain XCTest can call it.
    nonisolated static func linkPlacement(
        for route: RecipeRoute,
        external: Bool,
        originTab: AppTab
    ) -> LinkPlacement {
        if external {
            return LinkPlacement(tab: .feed, route: .replaceStack(route))
        }
        return LinkPlacement(tab: linkRoutingDestination(for: originTab), route: .push(route))
    }
}
