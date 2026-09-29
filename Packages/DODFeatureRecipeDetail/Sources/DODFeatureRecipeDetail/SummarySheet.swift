import DODDesignSystem
import SwiftUI

/// US-54 / T-932 (AC-54.2) — the on-device recipe/article summary result sheet.
///
/// Renders ``RecipeDetailViewModel/SummaryState``: a brief loading state while
/// the on-device model runs, the summary in a ``DODColor/surfaceElevated`` card
/// on success, and a graceful "No summary available" on `nil` (unavailable /
/// empty body / model error / guardrail rejection — the service never throws).
/// Read-only: it shows the summary, it changes nothing.
///
/// Copy conventions (CL-305 / feedback): Title Case heading + controls,
/// sentence-case body, no em dashes. Sheet dismissal is a top-right Done button
/// (CL — sheets dismiss with Done, pushes with the system chevron). Modeled on
/// `DODFeatureSaved`'s `SubstitutionSheet`.
struct SummarySheet: View {

    let state: RecipeDetailViewModel.SummaryState
    /// Called by the Done button; the host resets the state to `.idle`, which
    /// dismisses the sheet through its `isPresented` binding.
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(DODColor.surface)
                .navigationTitle("Summary")
                #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onDone() }
                            .tint(DODColor.accent)
                            .accessibilityIdentifier("dod.detail.summary.done")
                    }
                }
        }
        .accessibilityIdentifier("dod.detail.summary.sheet")
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            switch state {
            case .idle:
                EmptyView()
            case .loading:
                loadingBody
            case .loaded(let text):
                summaryCard(text)
            case .notFound:
                notFoundBody
            }

            Spacer(minLength: 0)
        }
        .padding(DODSpacing.lg)
    }

    /// Brief loading state while the on-device model runs.
    private var loadingBody: some View {
        HStack(spacing: DODSpacing.sm) {
            ProgressView()
                .tint(DODColor.accent)
            Text("Summarizing…")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Summarizing")
    }

    /// The summary, in a burnt-orange-accented elevated card.
    private func summaryCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Label {
                Text("On-device Summary")
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
        .accessibilityIdentifier("dod.detail.summary.result")
    }

    /// Graceful empty result — the model ran but had nothing, the body was
    /// empty, or it was unavailable at call time.
    private var notFoundBody: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("No summary available")
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
            Text("We couldn't summarize this one right now. Please try again later.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DODSpacing.md)
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        .accessibilityIdentifier("dod.detail.summary.empty")
    }
}

#Preview("Summary — loaded") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SummarySheet(
            state: .loaded(text: "A quick, weeknight-friendly cast-iron recipe with simple pantry ingredients."),
            onDone: {}
        )
    }
}

#Preview("Summary — loading") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SummarySheet(state: .loading, onDone: {})
    }
}

#Preview("Summary — not found") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SummarySheet(state: .notFound, onDone: {})
    }
}
