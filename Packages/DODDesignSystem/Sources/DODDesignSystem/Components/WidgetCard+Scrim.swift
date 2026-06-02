import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WidgetKit)
import WidgetKit
#endif

// Tint-safe contrast scrim for the featured ``WidgetCard.Small`` card.
// Split into its own file (mirroring `WidgetCard+Saved.swift` /
// `WidgetCard+LockScreen.swift`) so `WidgetCard.swift` stays under
// SwiftLint's 400-line `file_length` cap.
//
// Spec trace: spec.md US-23 / AC-23.7, DUT-9 (Tinted/Clear readability).
extension WidgetCard {

    /// Bottom-anchored darkening scrim that survives the iOS 18+ home-screen
    /// "Tinted" / "Vibrant" (`.accented` / `.vibrant`) rendering pass, so the
    /// `.white` title in ``Small`` stays legible over a bright recipe photo.
    ///
    /// **Why a `.fullColor` rasterised `Image` and not a `LinearGradient`
    /// (DUT-9 root cause).** The previous scrim was a plain translucent
    /// `LinearGradient` (`.clear` -> `.black.opacity(0.55)`). That works in
    /// Standard (`.fullColor`) mode but FAILS in Tinted/Clear mode: in
    /// `.accented` the system flattens the whole default content group into a
    /// single wallpaper-tinted silhouette where each pixel's *luminance*
    /// drives its alpha. A low-luminance translucent-black gradient
    /// contributes almost no alpha, so it all but disappears — the dark band
    /// the white title relied on is gone and the title collapses to a faint
    /// tint silhouette over the (`.fullColor`) photo. Worse, the prior
    /// attempts tried to protect the scrim with
    /// `widgetAccentedRenderingMode(.fullColor)`, but that modifier only
    /// exists on `Image`, not on `LinearGradient` or a `Group`/`VStack` — so
    /// it was either a no-op or applied at a scope that did nothing for the
    /// scrim. The only primitive that can opt OUT of accenting is an `Image`.
    ///
    /// The fix: bake the exact clear-to-black gradient into a `UIImage` once and
    /// render it as a `.resizable()` `Image` tagged
    /// `.widgetAccentedRenderingMode(.fullColor)`. Now the dark band keeps its
    /// true black pixels in every rendering mode, giving the title a
    /// guaranteed-dark backing — the same `.fullColor` photo-content technique
    /// Apple's Photos / Music widgets use. The opacity is raised to `0.70`
    /// (from `0.55`) for extra headroom against very light hero photos.
    ///
    /// `UIKit`-gated so the macOS `swift test` slice still builds; the macOS
    /// fallback is the original translucent gradient (macOS has no Tinted
    /// home-screen pass, so the desaturation bug can't occur there).
    struct TintSafeScrim: View {

        /// Peak opacity of the scrim at the very bottom edge.
        static let peakOpacity: CGFloat = 0.70

        var body: some View {
            #if canImport(UIKit) && canImport(WidgetKit)
            if #available(iOS 18.0, *), let baked = Self.bakedGradientImage {
                Image(uiImage: baked)
                    .resizable()
                    // Opt the scrim out of the Tinted/Vibrant desaturation
                    // pass so its true black survives — the crux of DUT-9.
                    .widgetAccentedRenderingMode(.fullColor)
            } else {
                Self.fallbackGradient
            }
            #else
            Self.fallbackGradient
            #endif
        }

        /// SwiftUI translucent gradient used pre-iOS-18 and on macOS, where
        /// there is no accented rendering pass to defeat.
        private static var fallbackGradient: some View {
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(peakOpacity)],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        #if canImport(UIKit)
        /// A tall, 1pt-wide vertical gradient from transparent at the top to
        /// `black @ peakOpacity` at the bottom, rasterised once and reused.
        /// `.resizable()` stretches the 1pt width across the card; the height
        /// is fixed at a generous 400px so the fade is smooth at every widget
        /// size. Built lazily and cached so the timeline-build cost is paid
        /// at most once per process.
        static let bakedGradientImage: UIImage? = {
            let size = CGSize(width: 1, height: 400)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                let cgContext = context.cgContext
                // `[CGColor]` bridges to the `CFArray` `CGGradient` wants.
                let colors: [CGColor] = [
                    UIColor.black.withAlphaComponent(0.0).cgColor,
                    UIColor.black.withAlphaComponent(peakOpacity).cgColor,
                ]
                guard
                    let gradient = CGGradient(
                        colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: colors as CFArray,
                        locations: [0.0, 1.0]
                    )
                else { return }
                cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: 0, y: size.height),
                    options: []
                )
            }
        }()
        #endif
    }
}
