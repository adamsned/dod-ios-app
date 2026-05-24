import SwiftUI
import WidgetKit

/// Extension entry point. WidgetKit discovers widgets by enumerating types
/// declared on the bundle's `body` property. Today we ship one widget kind
/// (`FeaturedRecipeWidget`); large + Lock Screen accessory sizes are
/// deferred — see `Marketing/TestFlight.md` and `specs/dod-ios-app/spec.md`
/// US-9 deferred-scope notes.
///
/// Spec trace: US-9.
@main
struct DODAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        FeaturedRecipeWidget()
    }
}
