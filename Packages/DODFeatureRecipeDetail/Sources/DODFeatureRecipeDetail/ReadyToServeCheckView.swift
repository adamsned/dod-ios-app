import DODDesignSystem
import DODDomain
import SwiftUI

/// DUT-987 — single-serving confidence check shown between the last Cook Mode
/// step and the journal log sheet.
struct ReadyToServeCheckView: View {
    let content: ReadyToServeContent
    /// Called when the cook taps the confirm button.
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var checked: Set<Int> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DODSpacing.lg) {
                    Text("Ready to serve?")
                        .dodFont(DODType.displayMedium)
                        .foregroundStyle(DODColor.label)
                    ForEach(Array(content.donenessCues.enumerated()), id: \.offset) { index, cue in
                        Button {
                            if checked.contains(index) { checked.remove(index) } else { checked.insert(index) }
                        } label: {
                            Label(cue, systemImage: checked.contains(index) ? "checkmark.circle.fill" : "circle")
                                .dodFont(DODType.body)
                                .foregroundStyle(DODColor.label)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("ready-to-serve-cue-\(index)")
                    }
                    VStack(alignment: .leading, spacing: DODSpacing.xs) {
                        Text("Plating tip").dodFont(DODType.body).foregroundStyle(DODColor.labelSecondary)
                        Text(content.platingTip).dodFont(DODType.body).foregroundStyle(DODColor.label)
                    }
                    Button("Looks great, I nailed it") {
                        onConfirm()
                        dismiss()
                    }
                    .dodProminentButton()
                    .tint(DODColor.accent)
                    .accessibilityIdentifier("ready-to-serve-confirm")
                }
                .padding(DODSpacing.md)
            }
            .background(DODColor.surface)
            .navigationTitle("Ready to Serve")
        }
    }
}
