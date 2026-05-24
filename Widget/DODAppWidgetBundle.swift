import SwiftUI
import WidgetKit

/// Extension entry point. WidgetKit discovers widgets by enumerating
/// types declared on the bundle's `body` property. Two widget kinds:
/// ``FeaturedRecipeWidget`` (US-9) and ``SavedRecipesWidget`` (US-17).
/// Order matters for the widget gallery — featured stays first to
/// preserve existing user muscle memory; saved appears second.
/// Large + Lock Screen accessory sizes are deferred — see
/// `Marketing/TestFlight.md` and `specs/dod-ios-app/spec.md` US-9
/// deferred-scope notes and US-17 CL-26.
///
/// Spec trace: US-9, US-17 (AC-17.1).
@main
struct DODAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        FeaturedRecipeWidget()
        SavedRecipesWidget()
    }
}
