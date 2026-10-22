import CoreGraphics
import XCTest

@testable import DODDesignSystem

/// L1 unit coverage for ``DownTailBubble``'s tail placement — the one piece of
/// ``TabBarCallout`` that has to be RIGHT for the component to mean anything: a
/// callout whose tail misses the tab it names is worse than no callout.
///
/// `tailCenterX` is pure (rect in, x out), so the aim is verifiable here without
/// booting a view or a simulator.
final class TabBarCalloutTailTests: XCTestCase {

    /// The App shell's real case: the Tools tab, 3rd of 4, on a 393pt-wide iPhone.
    private static let toolsFraction: CGFloat = 0.625
    private static let inset: CGFloat = DODSpacing.md
    private static let tailWidth: CGFloat = 18
    private static let radius: CGFloat = DODRadius.standard

    /// The bubble's rect for a given container (screen) width — it's inset by
    /// `inset` per side, which is exactly the offset the shape has to undo.
    private static func bubbleRect(containerWidth: CGFloat) -> CGRect {
        CGRect(x: inset, y: 0, width: containerWidth - inset * 2, height: 60)
    }

    private static func tailX(containerWidth: CGFloat, fraction: CGFloat) -> CGFloat {
        DownTailBubble.tailCenterX(
            in: bubbleRect(containerWidth: containerWidth),
            radius: radius,
            tailWidth: tailWidth,
            tailCenterFraction: fraction,
            horizontalInset: inset
        )
    }

    // MARK: - The fraction resolves to a real tab center

    /// The whole design: the tail's x, expressed in the bubble's own inset
    /// coordinate space, must land on the Tools tab's center in SCREEN space.
    func test_toolsTab_tailLandsOnTheTabCenter_iPhone393() {
        let width: CGFloat = 393
        // Screen-space center of item 3 of 4 in an evenly-distributed tab bar.
        let expected = width * Self.toolsFraction
        XCTAssertEqual(
            Self.tailX(containerWidth: width, fraction: Self.toolsFraction),
            expected,
            accuracy: 0.01
        )
    }

    /// The inset must be undone, not double-counted: a naive implementation that
    /// forgot the bubble is inset would put the tail `inset` points to the left.
    func test_tailIsExpressedInBubbleSpace_notScreenSpace() {
        let width: CGFloat = 393
        let x = Self.tailX(containerWidth: width, fraction: Self.toolsFraction)
        // Bubble space is screen space shifted left by `inset`, and the rect starts
        // at x = inset, so the returned value is still measured from the screen's
        // origin — but it must NOT be the un-adjusted `bubbleWidth * fraction`.
        let naive = (width - Self.inset * 2) * Self.toolsFraction
        XCTAssertNotEqual(x, naive, accuracy: 0.01)
    }

    /// It must hold across iPhone widths and orientations rather than being tuned
    /// to one device — the anchoring requirement.
    func test_tailTracksTheTabCenterAcrossWidths() {
        // SE, 15/17 Pro, Pro Max, and a landscape width.
        for width in [320, 375, 393, 430, 852] as [CGFloat] {
            XCTAssertEqual(
                Self.tailX(containerWidth: width, fraction: Self.toolsFraction),
                width * Self.toolsFraction,
                accuracy: 0.01,
                "tail should track the Tools tab center at width \(width)"
            )
        }
    }

    /// A centered tab is the zero-error case, and the outermost tabs are where a
    /// fraction-of-full-width aim is least exact — but all must stay on the flat
    /// run between the corners rather than being clamped away from their tab.
    func test_everyTabOfFour_getsADistinctInBoundsTail() {
        let width: CGFloat = 393
        let rect = Self.bubbleRect(containerWidth: width)
        let xs = (0..<4).map { index in
            Self.tailX(containerWidth: width, fraction: (CGFloat(index) + 0.5) / 4)
        }
        XCTAssertEqual(Set(xs).count, 4, "each tab should get its own tail position")
        for x in xs {
            XCTAssertGreaterThanOrEqual(x, rect.minX + Self.radius + Self.tailWidth / 2)
            XCTAssertLessThanOrEqual(x, rect.maxX - Self.radius - Self.tailWidth / 2)
        }
    }

    // MARK: - Clamping

    /// An outermost tab on a narrow screen would otherwise put the tail through a
    /// rounded corner; it must clamp onto the flat run instead of tearing the path.
    func test_extremeFractions_clampInsideTheCorners() {
        let width: CGFloat = 320
        let rect = Self.bubbleRect(containerWidth: width)
        let lowerBound = rect.minX + Self.radius + Self.tailWidth / 2
        let upperBound = rect.maxX - Self.radius - Self.tailWidth / 2

        XCTAssertEqual(Self.tailX(containerWidth: width, fraction: 0), lowerBound, accuracy: 0.01)
        XCTAssertEqual(Self.tailX(containerWidth: width, fraction: 1), upperBound, accuracy: 0.01)
    }

    /// A bubble too narrow to have a flat run between its corners must still
    /// produce a centered tail rather than an inverted, broken path.
    func test_implausiblyNarrowBubble_centersTheTail() {
        let rect = CGRect(x: 0, y: 0, width: 20, height: 60)
        let x = DownTailBubble.tailCenterX(
            in: rect,
            radius: Self.radius,
            tailWidth: Self.tailWidth,
            tailCenterFraction: Self.toolsFraction,
            horizontalInset: Self.inset
        )
        XCTAssertEqual(x, rect.midX, accuracy: 0.01)
    }
}
