#if canImport(UIKit)
import CoreGraphics
import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 coverage for the pure ``ProfilePhotoCropView/cropRect(for:offset:imageSize:cropDiameterInScreenPoints:displayedImageScaleFactor:)``,
/// ``ProfilePhotoCropView/displayedImageScaleFactor(imageSize:proxySize:)``,
/// and ``ProfilePhotoCropView/clampScale(_:)`` transform helpers.
/// Pinning these is load-bearing because the crop view's Done button
/// feeds the resulting rect to a renderer that bakes a 512×512 JPEG to
/// disk — a math drift here silently degrades every uploaded photo.
///
/// The view itself isn't snapshot-tested (gesture-driven layout doesn't
/// reproduce cleanly under `UIHostingController` snapshot hosts per
/// CL-137 alternative (g)); coverage of the underlying transform math
/// here gives the same regression guarantee with less flake.
///
/// **T-748 / CL-145 (DUT-54).** The pre-T-748 helper signature
/// `cropRect(for:offset:imageSize:cropSize:)` treated `offset` as source
/// pixels (it's actually screen pts) and `cropSize` as a normalized
/// fraction of the source's shorter side (it should be the on-screen
/// crop circle's diameter). The new signature accepts
/// `cropDiameterInScreenPoints` + `displayedImageScaleFactor` so the
/// helper can convert both offset + diameter into source pixels via
/// `displayedImageScaleFactor * scale`. The test cases in this file are
/// re-anchored against the new signature; the truth table covers the
/// identity, pan, zoom, clamp-to-edge, and defensive-guard paths.
///
/// Spec trace: US-44 AC-44.3; CL-137; CL-145.
@Suite("ProfilePhotoCropView math (T-740, amended T-748 / CL-145)")
struct ProfilePhotoCropMathTests {

    // MARK: - clampScale

    @Test func clampScaleAtLowerBoundIsPreserved() {
        let result = ProfilePhotoCropView.clampScale(ProfilePhotoCropView.scaleMin)
        #expect(result == ProfilePhotoCropView.scaleMin)
    }

    @Test func clampScaleAtUpperBoundIsPreserved() {
        let result = ProfilePhotoCropView.clampScale(ProfilePhotoCropView.scaleMax)
        #expect(result == ProfilePhotoCropView.scaleMax)
    }

    @Test func clampScaleBelowMinRaisesToFloor() {
        let result = ProfilePhotoCropView.clampScale(0.25)
        #expect(result == ProfilePhotoCropView.scaleMin)
    }

    @Test func clampScaleAboveMaxLowersToCeiling() {
        let result = ProfilePhotoCropView.clampScale(8.0)
        #expect(result == ProfilePhotoCropView.scaleMax)
    }

    @Test func clampScaleInsideRangeIsUnchanged() {
        let result = ProfilePhotoCropView.clampScale(2.5)
        #expect(result == 2.5)
    }

    // MARK: - displayedImageScaleFactor (T-748 / CL-145)

    @Test func scaleFactorPicksLimitingAxisForWideImageInPortraitProxy() {
        // Landscape source (4000×3000) inside a portrait proxy (400×800)
        // is width-bound: 400/4000 = 0.1; height ratio 800/3000 = 0.266.
        // `.scaledToFit()` picks the smaller of the two so the image
        // fits both axes — limiting axis is width here.
        let factor = ProfilePhotoCropView.displayedImageScaleFactor(
            imageSize: CGSize(width: 4_000, height: 3_000),
            proxySize: CGSize(width: 400, height: 800)
        )
        #expect(factor == 0.1)
    }

    @Test func scaleFactorPicksLimitingAxisForTallImageInPortraitProxy() {
        // Portrait source (3000×4000) inside a portrait proxy (400×800)
        // — width ratio 400/3000 ≈ 0.133, height ratio 800/4000 = 0.2.
        // Width-bound (smaller ratio).
        let factor = ProfilePhotoCropView.displayedImageScaleFactor(
            imageSize: CGSize(width: 3_000, height: 4_000),
            proxySize: CGSize(width: 400, height: 800)
        )
        #expect(abs(factor - (400.0 / 3_000.0)) < 0.0001)
    }

    @Test func scaleFactorIsZeroForDegenerateImage() {
        let factor = ProfilePhotoCropView.displayedImageScaleFactor(
            imageSize: .zero,
            proxySize: CGSize(width: 400, height: 800)
        )
        #expect(factor == 0)
    }

    @Test func scaleFactorIsZeroForDegenerateProxy() {
        let factor = ProfilePhotoCropView.displayedImageScaleFactor(
            imageSize: CGSize(width: 3_000, height: 4_000),
            proxySize: .zero
        )
        #expect(factor == 0)
    }

    // MARK: - cropRect — centered (no pan, no zoom)

    @Test func cropRectAtIdentityCentersOnImage() {
        // Square 1000×1000 image, scale 1, offset zero. Proxy is 400×800
        // → scaleFactor = 400/1000 = 0.4 (width-bound). Crop circle on
        // screen is 0.85 * 400 = 340pt. In source px: 340/0.4 = 850px.
        // Centered → rect (75, 75, 850, 850).
        let rect = ProfilePhotoCropView.cropRect(
            for: 1.0,
            offset: .zero,
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropDiameterInScreenPoints: 340,
            displayedImageScaleFactor: 0.4
        )
        #expect(rect.size.width == 850)
        #expect(rect.size.height == 850)
        #expect(rect.origin.x == 75)
        #expect(rect.origin.y == 75)
    }

    @Test func cropRectClampsToShorterSourceSideWhenCircleExceedsSource() {
        // Landscape source 1600×800 in a portrait proxy where the crop
        // circle in source-px would be 900 (wider than the source's
        // height of 800). Clamp to source's shorter side (800), centered.
        let rect = ProfilePhotoCropView.cropRect(
            for: 1.0,
            offset: .zero,
            imageSize: CGSize(width: 1_600, height: 800),
            cropDiameterInScreenPoints: 360,
            displayedImageScaleFactor: 0.4
            // 360 / 0.4 = 900 > shorterSide 800 → clamped to 800.
        )
        #expect(rect.size.width == 800)
        #expect(rect.size.height == 800)
        #expect(rect.origin.x == 400)  // centered horizontally: (1600-800)/2
        #expect(rect.origin.y == 0)
    }

    // MARK: - cropRect — zoomed in

    @Test func cropRectShrinksAsScaleIncreases() {
        // Same setup as identity (1000×1000, scaleFactor 0.4, crop 340pt).
        // At user scale 2.0 the divisor doubles → cropInSourcePx =
        // 340 / (0.4 * 2.0) = 425. Centered → rect (287.5, 287.5, 425, 425).
        let rect = ProfilePhotoCropView.cropRect(
            for: 2.0,
            offset: .zero,
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropDiameterInScreenPoints: 340,
            displayedImageScaleFactor: 0.4
        )
        #expect(rect.size.width == 425)
        #expect(rect.size.height == 425)
        #expect(rect.origin.x == 287.5)
        #expect(rect.origin.y == 287.5)
    }

    @Test func cropRectAtMaxScaleSamplesProportionalRegion() {
        // At user scale 4.0 (the locked max) the visible source side is
        // 1/4 of the scale-1.0 value: 340 / (0.4 * 4.0) = 212.5px.
        let rect = ProfilePhotoCropView.cropRect(
            for: 4.0,
            offset: .zero,
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropDiameterInScreenPoints: 340,
            displayedImageScaleFactor: 0.4
        )
        #expect(rect.size.width == 212.5)
        #expect(rect.size.height == 212.5)
    }

    // MARK: - cropRect — panned (T-748 / CL-145 unit conversion)

    @Test func cropRectPanRightConvertsScreenPtsToSourcePixels() {
        // T-748 / CL-145 — verifies the screen-pts → source-px conversion.
        // Drag 50pt right at scale 1.0 with scaleFactor 0.4: offset in
        // source pixels = 50 / (0.4 * 1.0) = 125. Crop center walks LEFT
        // by 125 (positive drag right = image moves right under fixed
        // crop window). At cropInSourcePx = 850 (340/0.4), halfSide=425.
        // Pre-pan center: (500, 500); post-pan: (500-125, 500) = (375, 500).
        // Clamp: halfSide=425, x-range [425, 575]. translatedX=375 → clamped to 425.
        // origin.x = 425 - 425 = 0.
        let rect = ProfilePhotoCropView.cropRect(
            for: 1.0,
            offset: CGSize(width: 50, height: 0),
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropDiameterInScreenPoints: 340,
            displayedImageScaleFactor: 0.4
        )
        // Clamps to the left edge for this configuration.
        #expect(rect.origin.x == 0)
        #expect(rect.size.width == 850)
        #expect(rect.origin.y == 75)
    }

    @Test func cropRectPanRightAtZoomShiftsTowardLeftOfImage() {
        // At scale 2.0 the crop circle in source-px shrinks to 425
        // (340 / (0.4 * 2.0)). Drag 60pt right → 60/(0.4*2.0)=75 source
        // pixels. Center walks from (500, 500) to (425, 500). halfSide
        // = 212.5; clamp range [212.5, 787.5] → translatedX=425 is in
        // range. origin.x = 425 - 212.5 = 212.5.
        let rect = ProfilePhotoCropView.cropRect(
            for: 2.0,
            offset: CGSize(width: 60, height: 0),
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropDiameterInScreenPoints: 340,
            displayedImageScaleFactor: 0.4
        )
        #expect(rect.size.width == 425)
        #expect(rect.origin.x == 212.5)
        #expect(rect.origin.y == 287.5)
    }

    @Test func cropRectClampsToLeftEdgeOnLargePanRight() {
        // Large positive drag right → crop tries to sample far LEFT of
        // image. Clamp to source x=0 so the renderer never samples
        // outside the source.
        let rect = ProfilePhotoCropView.cropRect(
            for: 2.0,
            offset: CGSize(width: 1_000, height: 0),
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropDiameterInScreenPoints: 340,
            displayedImageScaleFactor: 0.4
        )
        #expect(rect.origin.x == 0)
        #expect(rect.size.width == 425)
    }

    @Test func cropRectClampsToRightEdgeOnLargePanLeft() {
        // Large negative drag left → crop tries to sample far RIGHT of
        // image. Clamp to right boundary.
        let rect = ProfilePhotoCropView.cropRect(
            for: 2.0,
            offset: CGSize(width: -1_000, height: 0),
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropDiameterInScreenPoints: 340,
            displayedImageScaleFactor: 0.4
        )
        #expect(rect.size.width == 425)
        #expect(rect.origin.x == 575)  // 1000 - 425
    }

    // MARK: - cropRect — defensive guards

    @Test func cropRectHandlesZeroSideImageGracefully() {
        let rect = ProfilePhotoCropView.cropRect(
            for: 1.0,
            offset: .zero,
            imageSize: .zero,
            cropDiameterInScreenPoints: 340,
            displayedImageScaleFactor: 0.4
        )
        #expect(rect.size.width == 0)
        #expect(rect.size.height == 0)
    }

    @Test func cropRectHandlesZeroScaleGracefully() {
        let rect = ProfilePhotoCropView.cropRect(
            for: 0.0,
            offset: .zero,
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropDiameterInScreenPoints: 340,
            displayedImageScaleFactor: 0.4
        )
        #expect(rect.size.width == 1_000)
        #expect(rect.size.height == 1_000)
    }

    @Test func cropRectHandlesZeroScaleFactorGracefully() {
        // T-748 / CL-145 — a zero scaleFactor (degenerate proxy not yet
        // laid out) shouldn't divide by zero.
        let rect = ProfilePhotoCropView.cropRect(
            for: 1.0,
            offset: .zero,
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropDiameterInScreenPoints: 340,
            displayedImageScaleFactor: 0.0
        )
        #expect(rect.size.width == 1_000)
        #expect(rect.size.height == 1_000)
    }
}
#endif
