import SwiftUI
import WidgetKit

/// Extension entry point. WidgetKit discovers widgets by enumerating
/// types declared on the bundle's `body` property. Three widget kinds:
/// ``FeaturedRecipeWidget`` (US-9, home-screen `systemSmall` +
/// `systemMedium`), ``SavedRecipesWidget`` (US-17, home-screen
/// `systemSmall` + `systemMedium`), and ``LatestRecipeLockScreenWidget``
/// (US-22, lock-screen `.accessoryRectangular`).
/// Order matters for the widget gallery — featured stays first to
/// preserve existing user muscle memory; saved appears second; the new
/// lock-screen kind goes last so existing installs see the same first-
/// two ordering they had before T-370.
///
/// `.systemLarge` and the remaining accessory families
/// (`.accessoryCircular`, `.accessoryInline`) are deferred — see
/// `Marketing/TestFlight.md`, `specs/dod-ios-app/spec.md` US-9 deferred-
/// scope notes, US-17 CL-26 (large home-screen), and US-22 CL-37 (the
/// other accessory families).
///
/// Spec trace: US-9, US-17 (AC-17.1), US-22 (AC-22.1).
@main
struct DODAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        FeaturedRecipeWidget()
        SavedRecipesWidget()
        LatestRecipeLockScreenWidget()
    }
}
