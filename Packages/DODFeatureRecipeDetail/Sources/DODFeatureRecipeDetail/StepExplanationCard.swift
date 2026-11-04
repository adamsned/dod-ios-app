import DODDesignSystem
import DODIntelligence
import SwiftUI

/// DUT-1021 — tap-to-expand "Explain this step" affordance for Cook Mode.
struct StepExplanationCard: View {
    let state: StepExplainer.State
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            switch state {
            case .idle:
                Button(action: onTap) { Label("Explain this step", systemImage: "sparkles") }
                    .dodBorderedButton()
                    .accessibilityIdentifier("cook-mode-explain-step")
            case .loading:
                ProgressView().accessibilityLabel("Explaining this step")
            case .loaded(let result):
                Self.section("In plain words", result.expandedText)
                Self.section("Why it matters", result.whyItMatters)
                Self.section("Watch out for", result.commonMistake)
            case .unavailable:
                Text("Couldn't explain this step right now.")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.labelSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DODSpacing.md)
    }

    private static func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text(title).dodFont(DODType.body).foregroundStyle(DODColor.labelSecondary)
            Text(text).dodFont(DODType.body).foregroundStyle(DODColor.label)
        }
        .accessibilityElement(children: .combine)
    }
}
