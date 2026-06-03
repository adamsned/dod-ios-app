#if canImport(UIKit)
import CoreGraphics
import Foundation
import Testing

@testable import DODFeatureProfile

/// L1 coverage for the pure ``ProfilePhotoCropView/cropRect(for:offset:
/// imageSize:cropSize:)`` and ``ProfilePhotoCropView/clampScale(_:)``
/// transform helpers. Pinning these is load-bearing because the crop
/// view's Done button feeds the resulting rect to a renderer that bakes
/// a 512×512 JPEG to disk — a math drift here silently degrades every
/// uploaded photo.
///
/// The view itself isn't snapshot-tested (gesture-driven layout doesn't
/// reproduce cleanly under `UIHostingController` snapshot hosts per
/// CL-137 alternative (g)); coverage of the underlying transform math
/// here gives the same regression guarantee with less flake.
///
/// Spec trace: US-44 AC-44.3; CL-137.
@Suite("ProfilePhotoCropView math (T-740)")
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

    // MARK: - cropRect — centered (no pan, no zoom)

    @Test func cropRectAtIdentityCentersOnImage() {
        // Square 1000×1000 image, scale 1, offset zero — the crop should
        // land centered at the locked-square shorter side (1000) so the
        // visible rect is the entire image.
        let rect = ProfilePhotoCropView.cropRect(
            for: 1.0,
            offset: .zero,
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropSize: 1.0
        )
        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 0)
        #expect(rect.size.width == 1_000)
        #expect(rect.size.height == 1_000)
    }

    @Test func cropRectIsSquareOnNonSquareImage() {
        // Landscape image — shorter side is the height (800). Crop rect
        // is 800×800 centered horizontally on the image.
        let rect = ProfilePhotoCropView.cropRect(
            for: 1.0,
            offset: .zero,
            imageSize: CGSize(width: 1_600, height: 800),
            cropSize: 1.0
        )
        #expect(rect.size.width == rect.size.height)
        #expect(rect.size.width == 800)
        // Centered: origin.x = (1600 - 800) / 2 = 400
        #expect(rect.origin.x == 400)
        #expect(rect.origin.y == 0)
    }

    // MARK: - cropRect — zoomed in

    @Test func cropRectShrinksAsScaleIncreases() {
        // At scale 2.0 the visible source side is half (500 on a
        // 1000×1000 image with cropSize 1.0), centered.
        let rect = ProfilePhotoCropView.cropRect(
            for: 2.0,
            offset: .zero,
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropSize: 1.0
        )
        #expect(rect.size.width == 500)
        #expect(rect.size.height == 500)
        // Centered: origin (250, 250).
        #expect(rect.origin.x == 250)
        #expect(rect.origin.y == 250)
    }

    @Test func cropRectAtMaxScaleSamplesQuarterRegion() {
        // At scale 4.0 (the locked max) the visible source side is 1/4.
        let rect = ProfilePhotoCropView.cropRect(
            for: 4.0,
            offset: .zero,
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropSize: 1.0
        )
        #expect(rect.size.width == 250)
        #expect(rect.size.height == 250)
    }

    // MARK: - cropRect — panned (clamped)

    @Test func cropRectPanRightShiftsTowardLeftOfImage() {
        // Positive offset.width = the user dragged the image right on
        // screen, which means the crop is sampling further LEFT in
        // image coords. At scale 2.0 the visible side is 500; pan
        // offset 200 maps to -100 in image coords, so the center walks
        // left from (500,500) to (400,500).
        let rect = ProfilePhotoCropView.cropRect(
            for: 2.0,
            offset: CGSize(width: 200, height: 0),
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropSize: 1.0
        )
        #expect(rect.size.width == 500)
        // Center walks left → origin.x = 400 - 250 = 150
        #expect(rect.origin.x == 150)
        #expect(rect.origin.y == 250)
    }

    @Test func cropRectClampsToLeftEdge() {
        // Large pan that would walk the crop center off the left side
        // should clamp to the image-left boundary so the renderer
        // never samples outside the source.
        let rect = ProfilePhotoCropView.cropRect(
            for: 2.0,
            offset: CGSize(width: 1_000, height: 0),
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropSize: 1.0
        )
        // Visible side 500; clamp keeps the rect's left edge at zero.
        #expect(rect.origin.x == 0)
        #expect(rect.size.width == 500)
    }

    @Test func cropRectClampsToRightEdge() {
        // Negative offset.width = user dragged left, crop samples
        // further right. Should clamp to right boundary.
        let rect = ProfilePhotoCropView.cropRect(
            for: 2.0,
            offset: CGSize(width: -1_000, height: 0),
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropSize: 1.0
        )
        // Visible side 500; right edge clamps so origin.x = 500.
        #expect(rect.origin.x == 500)
        #expect(rect.size.width == 500)
    }

    // MARK: - cropRect — defensive guards

    @Test func cropRectHandlesZeroSideImageGracefully() {
        // A degenerate input shouldn't trap — returns the source rect
        // so the renderer noops.
        let rect = ProfilePhotoCropView.cropRect(
            for: 1.0,
            offset: .zero,
            imageSize: .zero,
            cropSize: 1.0
        )
        #expect(rect.size.width == 0)
        #expect(rect.size.height == 0)
    }

    @Test func cropRectHandlesZeroScaleGracefully() {
        // Defensive: a zero scale (impossible in practice — the clamp
        // raises to scaleMin) shouldn't cause a divide-by-zero.
        let rect = ProfilePhotoCropView.cropRect(
            for: 0.0,
            offset: .zero,
            imageSize: CGSize(width: 1_000, height: 1_000),
            cropSize: 1.0
        )
        // Returns the source rect for the degenerate case.
        #expect(rect.size.width == 1_000)
        #expect(rect.size.height == 1_000)
    }
}
#endif
