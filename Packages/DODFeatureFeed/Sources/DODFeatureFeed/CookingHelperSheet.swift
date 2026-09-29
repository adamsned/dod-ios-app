import DODDesignSystem
import SwiftUI

/// T-934 (US-54 / AC-54.4) — the Cooking Tools "Ask Dutch Oven Daddy" helper
/// sheet: a text field for a cast-iron / Dutch-oven / technique question, an
/// "Ask" button, and the on-device model's answer.
///
/// Renders ``CookingHelperViewModel/AnswerState``: nothing while `.idle`, a
/// brief "Thinking…" spinner while the on-device model runs, the answer in a
/// ``DODColor/surfaceElevated`` card on success, and a graceful "No answer
/// available" on `.notFound` (unavailable / empty / model error / guardrail
/// rejection — the service never throws). Modeled on the substitution result
/// sheet (`SubstitutionSheet`).
///
/// Copy conventions (CL-305 / feedback): Title Case heading + the "Ask"
/// control; sentence-case body, placeholder, and messages; no em dashes. Sheet
/// dismissal is a top-right Done button (sheets dismiss with Done, pushes with
/// the system chevron).
public struct CookingHelperSheet: View {

    @Bindable var viewModel: CookingHelperViewModel
    /// Called by the Done button; the host resets the view model to `.idle`,
    /// which dismisses the sheet through its `isPresented` binding.
    let onDone: () -> Void

    public init(viewModel: CookingHelperViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    private var trimmedQuestion: String {
        viewModel.question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isLoading: Bool {
        viewModel.answer == .loading
    }

    public var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(DODColor.surface)
                .navigationTitle("Cooking Helper")
                #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onDone() }
                            .tint(DODColor.accent)
                            .accessibilityIdentifier("dod.cookingTools.helper.done")
                    }
                }
        }
        .accessibilityIdentifier("dod.cookingTools.helper.sheet")
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            Text("Ask about cast iron, Dutch ovens, or technique.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)

            questionField
            askButton
            answerBody

            Spacer(minLength: 0)
        }
        .padding(DODSpacing.lg)
    }

    /// The question input, on an elevated card so it reads as a distinct field.
    private var questionField: some View {
        TextField(
            "Ask about cast iron, Dutch ovens, or technique…",
            text: $viewModel.question,
            axis: .vertical
        )
        .dodFont(DODType.body)
        .lineLimit(1...4)
        .textFieldStyle(.plain)
        .padding(DODSpacing.md)
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        .disabled(isLoading)
        .accessibilityIdentifier("dod.cookingTools.helper.questionField")
    }

    /// The Title-Case "Ask" control. Disabled while the question is blank or the
    /// model is running, so a spurious tap can't stack requests.
    private var askButton: some View {
        Button {
            Task { await viewModel.ask() }
        } label: {
            Text("Ask")
                .dodFont(DODType.bodyEmphasized)
                .padding(.horizontal, DODSpacing.lg)
                .padding(.vertical, DODSpacing.sm)
        }
        .dodProminentButton()
        .tint(DODColor.accent)
        .disabled(trimmedQuestion.isEmpty || isLoading)
        .accessibilityIdentifier("dod.cookingTools.helper.askButton")
    }

    @ViewBuilder
    private var answerBody: some View {
        switch viewModel.answer {
        case .idle:
            EmptyView()
        case .loading:
            loadingBody
        case .loaded(let text):
            answerCard(text)
        case .notFound:
            notFoundBody
        }
    }

    /// Brief loading state while the on-device model runs.
    private var loadingBody: some View {
        HStack(spacing: DODSpacing.sm) {
            ProgressView()
                .tint(DODColor.accent)
            Text("Thinking…")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Thinking")
    }

    /// The answer, in an elevated card.
    private func answerCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Label {
                Text("Answer")
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.label)
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundStyle(DODColor.accent)
            }

            Text(text)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DODSpacing.md)
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dod.cookingTools.helper.answerCard")
    }

    /// Graceful empty result — the model ran but had nothing, or was
    /// unavailable at call time.
    private var notFoundBody: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("No answer available")
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
            Text("We couldn't answer that one. Try rewording your question.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DODSpacing.md)
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        .accessibilityIdentifier("dod.cookingTools.helper.noAnswer")
    }
}
