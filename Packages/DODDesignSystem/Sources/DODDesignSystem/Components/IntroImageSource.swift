import SwiftUI

/// A reference to a bundled still image for the App Intro media area.
///
/// Mirrors ``IntroVideoSource``, but for a static asset-catalog image instead
/// of a looping clip. Deliberately thin — it wraps the asset-catalog name of an
/// image bundled in this module, which keeps ``AppIntroTour/Page`` `Sendable`
/// (a `String` is trivially so) and lets the view resolve it via
/// `Bundle.module` at render time.
///
/// The image is shown aspect-fit (never cropped) in the same media box the
/// SF-symbol placeholder and ``IntroVideoSource`` clips use, so image, video,
/// and symbol slides mix freely (media precedence: video → image → symbol).
///
/// ## Shipping asset
///
/// ``logo`` points at the Dutch Oven Daddy badge (`dod-logo-badge`, a
/// transparent PNG in `Resources/Media.xcassets`) — the opening slide's welcome
/// visual (DUT-336).
public struct IntroImageSource: Sendable {
    /// The name of an image in this module's asset catalog.
    public let assetName: String

    public init(assetName: String) {
        self.assetName = assetName
    }

    /// The Dutch Oven Daddy circular badge ("Cast Iron Living"), a transparent
    /// PNG bundled in DODDesignSystem. Used as the App Intro opening slide's
    /// visual (DUT-336).
    public static let logo = IntroImageSource(assetName: "dod-logo-badge")
}
