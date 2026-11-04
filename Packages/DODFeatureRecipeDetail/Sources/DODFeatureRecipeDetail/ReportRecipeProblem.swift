import DODAnalytics
import DODDesignSystem
import SwiftUI

/// DUT-178 — the "Report a problem with this recipe" link. Owns its own sheet state.
struct ReportRecipeProblemButton: View {
    let recipeID: Int
    let recipeTitle: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label("Report a problem with this recipe", systemImage: "exclamationmark.bubble")
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.accent)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DODSpacing.md)
        .accessibilityIdentifier("dod.detail.reportProblem")
        .sheet(isPresented: $isPresented) {
            ReportRecipeProblemSheet(recipeID: recipeID, recipeTitle: recipeTitle)
        }
    }
}

/// Problem-type picker + optional note; hands the report to the mail composer via `openURL`.
struct ReportRecipeProblemSheet: View {
    let recipeID: Int
    let recipeTitle: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var problemType: RecipeProblemType = .ingredient
    @State private var note = ""
    @State private var didSend = false

    private var report: RecipeProblemReport {
        RecipeProblemReport(recipeID: recipeID, recipeTitle: recipeTitle, problemType: problemType, note: note)
    }

    var body: some View {
        NavigationStack {
            Group {
                if didSend { confirmation } else { form }
            }
            .navigationTitle("Report a Problem")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didSend ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("report-recipe-problem-sheet")
    }

    private var form: some View {
        Form {
            Section(recipeTitle) {
                Picker("Problem", selection: $problemType) {
                    ForEach(RecipeProblemType.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
                .accessibilityIdentifier("report-problem-type")
            }
            Section("Note (optional)") {
                TextEditor(text: $note)
                    .frame(minHeight: 100)
                    .accessibilityIdentifier("report-problem-note")
            }
            Text("Sent privately to the Dutch Oven Daddy team by email. It is not posted as a comment.")
                .dodFont(DODType.caption)
                .foregroundColor(.secondary)
            Button("Send") { submit() }
                .accessibilityIdentifier("report-problem-send")
        }
    }

    private var confirmation: some View {
        VStack(spacing: DODSpacing.md) {
            Text("Thanks — we'll check it out")
                .dodFont(DODType.body)
                .accessibilityIdentifier("report-problem-confirmation")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func submit() {
        guard let url = report.mailtoURL else { return }
        openURL(url)
        Telemetry.shared.send(.recipeProblemReported(recipeID: recipeID, problemType: problemType.rawValue))
        didSend = true
    }
}
