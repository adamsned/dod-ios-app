import SwiftUI

/// A slim, dismissible "speech bubble" that floats just above the bottom tab bar
/// and points DOWN at one specific tab item.
///
/// It is deliberately generic (no feature knowledge): the host supplies the copy,
/// the icon, and `tailCenterFraction` — where, as a 0...1 fraction of the FULL
/// container width, the tail should aim. The first consumer is the App shell's
/// First Cookout callout, which aims at the Cooking Tools ("Tools") tab.
///
/// **Why a fraction, not an anchor preference:** the bottom tab bar is UIKit's
/// (`TabView`'s) own chrome — the host app doesn't own the tab item views, so
/// there is no SwiftUI `anchorPreference` to read a tab button's frame from.
/// The tab bar distributes its items EVENLY, so item `i` of `n` is centered at
/// `(i + 0.5) / n` of the bar's width. See ``tailCenterFraction`` for the
/// accuracy this buys and where it degrades.
///
/// Reduce Motion / entrance animation is the HOST's business — this view is
/// static, so the host gates its own `.transition` / `.animation`.
public struct TabBarCallout: View {

    /// One short line of body copy (sentence case).
    private let message: String
    /// Optional leading SF Symbol, tinted burnt orange. Icon-only accent use, per
    /// the design convention that burnt orange is never a full content-card fill.
    private let systemImage: String?
    /// Where the tail points, as a fraction (0...1) of the FULL container width —
    /// NOT of the bubble, which is inset by ``horizontalInset``. The shape
    /// reconstructs the container width from its own rect plus the inset, so the
    /// caller can express this purely in tab-bar terms: `(index + 0.5) / count`.
    ///
    /// **Accuracy.** A tab bar's items are evenly distributed across the bar, and
    /// the bar is symmetric about the container's horizontal center. If the bar
    /// itself is inset from the container edges by `m` per side (iOS 26 renders a
    /// floating capsule rather than an edge-to-edge bar), the true center of item
    /// `i` is `w/2 + (f - 0.5) * (w - 2m)` while this fraction yields
    /// `w/2 + (f - 0.5) * w` — an error of `(f - 0.5) * 2m`. For the 3rd of 4 tabs
    /// (`f = 0.625`) and a generous `m = 20pt`, that's 5pt of drift against a
    /// ~90pt-wide tab slot: the tail still lands well inside the intended item.
    /// The error is ZERO for a centered item and grows toward the outermost tabs,
    /// so this stays visually correct across iPhone widths and orientations.
    private let tailCenterFraction: CGFloat
    /// How far the bubble is inset from the container's horizontal edges. The
    /// component applies this itself (rather than leaving it to the caller) so the
    /// tail's fraction→point conversion can't silently disagree with the layout.
    private let horizontalInset: CGFloat
    /// Tapping the bubble body (anywhere but the X) activates it.
    private let onActivate: () -> Void
    /// The X button.
    private let onDismiss: () -> Void
    private let accessibilityID: String
    private let dismissAccessibilityID: String
    /// VoiceOver name for the bubble's activate action.
    private let activateActionName: String

    /// Height of the downward tail; also the bubble's extra bottom inset so the
    /// content never overlaps it.
    private static let tailHeight: CGFloat = 9
    private static let tailWidth: CGFloat = 18

    public init(
        message: String,
        systemImage: String? = nil,
        tailCenterFraction: CGFloat,
        horizontalInset: CGFloat = DODSpacing.md,
        accessibilityID: String,
        dismissAccessibilityID: String,
        activateActionName: String,
        onActivate: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.message = message
        self.systemImage = systemImage
        self.tailCenterFraction = tailCenterFraction
        self.horizontalInset = horizontalInset
        self.accessibilityID = accessibilityID
        self.dismissAccessibilityID = dismissAccessibilityID
        self.activateActionName = activateActionName
        self.onActivate = onActivate
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: DODSpacing.xs) {
            if let systemImage {
                // Icon-only accent (never a full fill) — and it echoes the tab
                // glyph the tail points at, tying the bubble to its target.
                Image(systemName: systemImage)
                    .foregroundStyle(DODColor.burntOrange)
                    .accessibilityHidden(true)
            }
            Text(message)
                .dodFont(DODType.detail)
                .foregroundStyle(DODColor.label)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DODColor.labelSecondary)
                    // 44pt minimum tap target.
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Dismiss")
            .accessibilityIdentifier(dismissAccessibilityID)
        }
        .padding(.leading, DODSpacing.md)
        // The X button carries its own 44pt frame, so it needs almost no
        // trailing padding of its own — this keeps the bubble slim.
        .padding(.trailing, DODSpacing.xxs)
        .padding(.vertical, DODSpacing.xxs)
        .padding(.bottom, Self.tailHeight)
        .background(
            // The bubble floats over scrolling feed content, so it needs a
            // shadow to separate from it (matches DODSearchField's elevation).
            bubbleShape
                .fill(DODColor.surfaceElevated)
                .shadow(color: DODColor.charcoal.opacity(0.12), radius: 6, x: 0, y: 2)
        )
        .overlay(bubbleShape.stroke(DODColor.burntOrange.opacity(0.3), lineWidth: 1))
        .contentShape(bubbleShape)
        .onTapGesture { onActivate() }
        .padding(.horizontal, horizontalInset)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityID)
        // A bare `.onTapGesture` is invisible to VoiceOver — give the bubble the
        // button trait plus a default activate action (mirrors the retired
        // Cooking Tools callout's DUT-286 fix).
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onActivate() }
        .accessibilityAction(named: Text(activateActionName)) { onActivate() }
    }

    private var bubbleShape: DownTailBubble {
        DownTailBubble(
            tailWidth: Self.tailWidth,
            tailHeight: Self.tailHeight,
            tailCenterFraction: tailCenterFraction,
            horizontalInset: horizontalInset
        )
    }
}

/// A rounded-rectangle bubble with a small triangular tail on the BOTTOM edge, so
/// it reads as pointing down at the tab-bar item beneath it. Mirrors the retired
/// `CookingToolsCallout`'s upward `SpeechBubble`, flipped and with a caller-driven
/// horizontal tail position instead of a fixed trailing inset.
struct DownTailBubble: Shape {

    var cornerRadius: CGFloat = DODRadius.standard
    var tailWidth: CGFloat = 18
    var tailHeight: CGFloat = 9
    /// See ``TabBarCallout/tailCenterFraction``.
    var tailCenterFraction: CGFloat
    /// See ``TabBarCallout/horizontalInset``.
    var horizontalInset: CGFloat

    /// The tail's center X in the bubble's own coordinate space, clamped so the
    /// triangle always sits on the flat run between the two bottom corner arcs
    /// (an unclamped tail would tear through a rounded corner). Exposed
    /// (non-private, `static`, pure) so it's unit-testable without a SwiftUI host.
    static func tailCenterX(
        in rect: CGRect,
        radius: CGFloat,
        tailWidth: CGFloat,
        tailCenterFraction: CGFloat,
        horizontalInset: CGFloat
    ) -> CGFloat {
        // The bubble is inset by `horizontalInset` per side, so the container it
        // (and the tab bar) is measured against is that much wider.
        let containerWidth = rect.width + horizontalInset * 2
        let raw = containerWidth * tailCenterFraction - horizontalInset + rect.minX
        let lowerBound = rect.minX + radius + tailWidth / 2
        let upperBound = rect.maxX - radius - tailWidth / 2
        // On an implausibly narrow bubble the bounds can invert; center the tail
        // rather than emitting a broken path.
        guard lowerBound <= upperBound else { return rect.midX }
        return min(max(raw, lowerBound), upperBound)
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bodyBottom = rect.maxY - tailHeight
        let radius = max(0, min(cornerRadius, (rect.height - tailHeight) / 2))
        let tailX = Self.tailCenterX(
            in: rect,
            radius: radius,
            tailWidth: tailWidth,
            tailCenterFraction: tailCenterFraction,
            horizontalInset: horizontalInset
        )

        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: bodyBottom - radius))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: bodyBottom - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        // The downward tail.
        path.addLine(to: CGPoint(x: tailX + tailWidth / 2, y: bodyBottom))
        path.addLine(to: CGPoint(x: tailX, y: rect.maxY))
        path.addLine(to: CGPoint(x: tailX - tailWidth / 2, y: bodyBottom))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: bodyBottom))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: bodyBottom - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack {
        Spacer()
        TabBarCallout(
            message: "New to cast iron? Your First Cookout starts here.",
            systemImage: "frying.pan.fill",
            // 3rd of 4 tabs.
            tailCenterFraction: 0.625,
            accessibilityID: "first-cookout-callout",
            dismissAccessibilityID: "first-cookout-callout-dismiss",
            activateActionName: "Open Your First Cookout",
            onActivate: {},
            onDismiss: {}
        )
    }
    .background(DODColor.surface)
}
