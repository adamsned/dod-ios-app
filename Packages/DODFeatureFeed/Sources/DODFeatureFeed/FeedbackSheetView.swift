import DODAnalytics
import DODDesignSystem
import SwiftUI

public struct FeedbackSheetView: View {
    /// Stable id of the screen the user was on ("feed", "saved", "settings", ...).
    private let currentScreen: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var category: FeedbackCategory = .bug
    @State private var text = ""
    @State private var includeDiagnostics = false
    @State private var didSend = false

    public init(currentScreen: String) { self.currentScreen = currentScreen }

    private var report: FeedbackReport {
        FeedbackReport(
            category: category,
            text: text,
            diagnostics: includeDiagnostics ? .current(screen: currentScreen) : nil
        )
    }

    public var body: some View {
        NavigationStack {
            Group { if didSend { confirmation } else { form } }
                .navigationTitle("Send Feedback")
                #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(didSend ? "Done" : "Cancel") { dismiss() }
                    }
                }
        }
        .onAppear { Telemetry.shared.send(.feedbackStarted) }
        .accessibilityIdentifier("feedback-sheet")
    }

    private var form: some View {
        Form {
            Picker("Category", selection: $category) {
                ForEach(FeedbackCategory.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("feedback-category")
            TextEditor(text: $text).frame(minHeight: 140)
                .accessibilityIdentifier("feedback-text")
            Toggle("Include diagnostic info", isOn: $includeDiagnostics)
                .accessibilityIdentifier("feedback-diagnostics-toggle")
            Text("Adds app version, OS version, device model and current screen. Nothing personal is sent.")
                .dodFont(.caption).foregroundColor(.secondary)
            Button("Send") { submit() }
                .disabled(!report.isSubmittable)
                .accessibilityIdentifier("feedback-send")
        }
    }

    private var confirmation: some View {
        VStack(spacing: DODSpacing.md) {
            Text("Thanks — we read every message").dodFont(.body)
                .accessibilityIdentifier("feedback-confirmation")
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func submit() {
        guard let url = report.mailtoURL else { return }
        openURL(url)
        Telemetry.shared.send(.feedbackSent(category: category.rawValue))
        didSend = true
    }
}
