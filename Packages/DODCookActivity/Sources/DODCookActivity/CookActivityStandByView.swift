import DODDesignSystem
import SwiftUI

/// DUT-991: full-screen StandBy / countertop presentation of the cook timer.
public struct CookActivityStandByView: View {
    public let recipeTitle: String
    public let model: CookActivityStandByModel
    /// StandBy night mode (red-tinted, luminance reduced): drop accent colour.
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    public init(recipeTitle: String, model: CookActivityStandByModel) {
        self.recipeTitle = recipeTitle
        self.model = model
    }

    public var body: some View {
        VStack(spacing: DODSpacing.sm) {
            Text(recipeTitle)
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(DODColor.labelSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            countdown
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(numeralColor)
                .accessibilityLabel(accessibilityLabel)
            if model.status == .done {
                Text("Done").font(.system(.title, weight: .bold)).foregroundStyle(numeralColor)
            } else if model.status == .paused {
                Text("Paused").font(.system(.title2, weight: .medium)).foregroundStyle(DODColor.labelSecondary)
            }
            Text(model.stepText)
                .font(.system(.title2))
                .foregroundStyle(DODColor.label)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
        .padding(DODSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var countdown: Text {
        if let range = model.tickingRange { return Text(timerInterval: range, countsDown: true) }
        return Text(model.staticCountdown)
    }

    private var numeralColor: Color {
        if isLuminanceReduced { return DODColor.label }
        return model.status == .paused ? DODColor.labelSecondary : DODColor.accent
    }

    private var accessibilityLabel: String {
        switch model.status {
        case .done: return "Timer complete"
        case .paused: return "Time remaining, paused"
        case .running: return "Time remaining"
        }
    }
}
