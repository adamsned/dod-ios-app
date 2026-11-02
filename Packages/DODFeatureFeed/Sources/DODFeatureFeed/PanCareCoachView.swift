import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-971 — post-cook "wipe, oil, done" care prompt.
public struct PanCareCoachView: View {
    let onLogCare: () -> Void
    let onSkip: () -> Void

    /// Bump on appear to fire a one-shot success haptic (same pattern as CookCelebrationView).
    @State private var appearTick = 0

    public init(onLogCare: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.onLogCare = onLogCare
        self.onSkip = onSkip
    }

    /// Exposed for tests.
    static let headline = "Quick pan care — 30 seconds"
    static var steps: [PanCareStep] { PanCareStep.allCases }

    public var body: some View {
        VStack(spacing: DODSpacing.md) {
            Text(Self.headline)
                .dodFont(DODType.displayMedium)
                .foregroundStyle(DODColor.label)
                .multilineTextAlignment(.center)
            ForEach(Self.steps, id: \.self) { step in
                VStack(spacing: DODSpacing.xs) {
                    Text(step.title)
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.burntOrange)
                        .textCase(.uppercase)
                    Text(step.instruction)
                        .dodFont(DODType.body)
                        .foregroundStyle(DODColor.labelSecondary)
                        .multilineTextAlignment(.center)
                }
                .accessibilityElement(children: .combine)
            }
            Spacer()
            Button("I did it") { onLogCare() }
                .dodProminentButton()
                .tint(DODColor.burntOrange)
            Button("Not now") { onSkip() }
        }
        .padding(DODSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DODColor.surface.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: appearTick)
        .onAppear { appearTick &+= 1 }
    }
}
