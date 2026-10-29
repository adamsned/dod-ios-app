import DODDesignSystem
import DODSupport
import SwiftUI

/// DUT-970 — in-cook mistake recovery. Presented as a sheet over Cook Mode.
struct CookModeRescueSheet: View {
    let heatProfile: RecipeHeatProfile.Derived?
    @State private var selected: CastIronRescue.Problem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DODSpacing.md) {
                    ForEach(CastIronRescue.Problem.allCases) { problem in
                        Button {
                            selected = problem
                        } label: {
                            Text(problem.title)
                                .dodFont(DODType.bodyEmphasized)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cook-mode-rescue-\(problem.rawValue)")
                    }
                    if let selected { detail(for: selected) }
                }
                .padding(DODSpacing.md)
            }
            .navigationTitle("Something not going right?")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    @ViewBuilder
    private func detail(for problem: CastIronRescue.Problem) -> some View {
        let rescue = CastIronRescue.rescue(for: problem)
        VStack(alignment: .leading, spacing: DODSpacing.sm) {
            Text(rescue.reassurance).dodFont(DODType.bodyEmphasized)
            ForEach(Array(rescue.steps.enumerated()), id: \.offset) { index, step in
                Text("\(index + 1). \(step)")
            }
            if let tip = CastIronRescue.heatTip(for: problem, profile: heatProfile) {
                Text(tip).foregroundStyle(DODColor.accent)
            }
        }
        .accessibilityIdentifier("cook-mode-rescue-detail")
    }
}
