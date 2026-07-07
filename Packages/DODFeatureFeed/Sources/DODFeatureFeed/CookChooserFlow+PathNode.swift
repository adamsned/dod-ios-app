import DODDesignSystem
import DODSupport
import SwiftUI

/// One stop on the "Your First Cookout" roadmap (CL-265): a rail node (numbered
/// circle + the connector line down to the next stop) beside a tappable dish
/// card. The node encodes the cook's progress along ``GuidedCookout/path`` —
/// **done** (a filled checkmark + walked trail), **current** (the highlighted
/// "start here" target), or **upcoming** (an outlined number + the road ahead) —
/// so the chooser reads as a journey, not a list. Split from
/// `CookChooserFlow.swift` to keep each file under SwiftLint's 400-line cap.
struct CookPathNode: View {

    enum NodeState: Equatable { case done, current, upcoming }

    let rung: GuidedCookout
    let number: Int
    let state: NodeState
    let isLast: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DODSpacing.sm) {
            rail
            card
        }
    }

    // MARK: - Rail (node + connector to the next stop)

    private var rail: some View {
        VStack(spacing: 0) {
            node
            if !isLast {
                Rectangle()
                    .fill(connectorColor)
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 48)
        // The bare node symbol (a number, checkmark, or flame) is read by VO
        // before every roadmap card, but the card's `statePill` already conveys
        // done / current / upcoming — so hide the decorative rail from VO.
        .accessibilityHidden(true)
    }

    private var node: some View {
        ZStack {
            if state == .current {
                Circle()
                    .fill(DODColor.burntOrange.opacity(0.18))
                    .frame(width: 48, height: 48)
            }
            Circle()
                .fill(nodeFill)
                .frame(width: 38, height: 38)
            Circle()
                .strokeBorder(nodeStroke, lineWidth: 2)
                .frame(width: 38, height: 38)
            nodeSymbol
        }
        .frame(width: 48, height: 48)
    }

    @ViewBuilder private var nodeSymbol: some View {
        switch state {
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DODColor.labelOnAccent)
        case .current, .upcoming:
            if rung.isCampfire {
                Image(systemName: "flame.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(symbolColor)
            } else {
                Text("\(number)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(symbolColor)
            }
        }
    }

    // MARK: - Card

    private var card: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: DODSpacing.xs) {
                    Text(rung.dishTitle)
                        .dodFont(DODType.heading)
                        .foregroundStyle(DODColor.label)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    statePill
                }
                Text(rung.pathHook)
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DODSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                DODColor.surfaceElevated,
                in: RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
            )
            .overlay {
                if state == .current {
                    RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                        .strokeBorder(DODColor.burntOrange, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.bottom, isLast ? 0 : DODSpacing.md)
        .accessibilityIdentifier("cook-chooser-rung-\(rung.recipeID)")
    }

    @ViewBuilder private var statePill: some View {
        switch state {
        case .current:
            Text(currentPillText)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelOnAccent)
                .padding(.horizontal, DODSpacing.xs)
                .padding(.vertical, DODSpacing.xxs)
                .background(DODColor.burntOrange, in: Capsule())
        case .done:
            HStack(spacing: DODSpacing.xxs) {
                Image(systemName: "checkmark")
                Text("Cooked")
            }
            .dodFont(DODType.caption)
            .foregroundStyle(DODColor.labelSecondary)
        case .upcoming:
            EmptyView()
        }
    }

    private var currentPillText: String {
        if rung.isFirstRung { return "START HERE" }
        if rung.isCampfire { return "THE CAMPFIRE" }
        return "YOUR NEXT WIN"
    }

    // MARK: - Colors

    private var nodeFill: Color {
        switch state {
        case .done, .current: DODColor.burntOrange
        case .upcoming: DODColor.surfaceElevated
        }
    }

    private var nodeStroke: Color {
        switch state {
        case .done, .current: .clear
        case .upcoming: DODColor.burntOrange.opacity(0.4)
        }
    }

    private var symbolColor: Color {
        state == .current ? DODColor.labelOnAccent : DODColor.burntOrange
    }

    /// The trail already walked (below a done node) is solid burnt-orange; the
    /// road ahead (below the current / an upcoming node) is a muted tint.
    private var connectorColor: Color {
        switch state {
        case .done: DODColor.burntOrange
        case .current, .upcoming: DODColor.burntOrange.opacity(0.2)
        }
    }
}

extension GuidedCookout {
    /// A short motivating hook for the roadmap card: the first sentence of
    /// ``whyThisDish`` (the full "why" shows inside the coached flow).
    var pathHook: String {
        guard let dot = whyThisDish.firstIndex(of: ".") else { return whyThisDish }
        return String(whyThisDish[...dot])
    }
}
