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

    /// `true` for a **transparent** still (e.g. a device-framed app screenshot
    /// exported as a PNG with a clear background). The view then floats it
    /// directly on the slide's own Flour/Cocoa background — no card or circle —
    /// so it matches the transparent video slides and one PNG works in both
    /// light and dark. `false` (the default) keeps the badge treatment: a soft
    /// cream circle so a logo reads as a self-contained coin on both grounds.
    public let isTransparent: Bool

    public init(assetName: String, isTransparent: Bool = false) {
        self.assetName = assetName
        self.isTransparent = isTransparent
    }

    /// The Dutch Oven Daddy circular badge ("Cast Iron Living"), a transparent
    /// PNG bundled in DODDesignSystem. Used as the App Intro opening slide's
    /// visual (DUT-336).
    public static let logo = IntroImageSource(assetName: "dod-logo-badge")
}
