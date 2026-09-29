import DODDesignSystem
import DODIntelligence
import SwiftUI

/// v2 on-device AI (1/n) — the ingredient-substitution result sheet.
///
/// Renders ``ShoppingListViewModel/SubstitutionState``: a brief loading state
/// while the on-device model runs, the suggestion in a
/// ``DODColor/surfaceElevated`` card on success, and a graceful "no substitute
/// found" on `nil` (unavailable / model error / guardrail rejection — the
/// service never throws). Read-only for v1: it shows the suggestion, it does
/// NOT add anything to the list.
///
/// Copy conventions (CL-305 / feedback): Title Case heading, sentence-case
/// body, no em dashes. Sheet dismissal is a top-right Done button (CL — sheets
/// dismiss with Done, pushes with the system chevron).
struct SubstitutionSheet: View {

    let state: ShoppingListViewModel.SubstitutionState
    /// Called by the Done button; the host resets the state to `.idle`, which
    /// dismisses the sheet through its `isPresented` binding.
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(DODColor.surface)
                .navigationTitle("Substitute")
                #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onDone() }
                            .tint(DODColor.accent)
                            .accessibilityIdentifier("shopping-substitution-done")
                    }
                }
        }
        .accessibilityIdentifier("shopping-substitution-sheet")
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            if let ingredient = state.ingredient {
                Text("Substitute For \(ingredient)")
                    .dodFont(DODType.displayMedium)
                    .foregroundStyle(DODColor.label)
                    .fixedSize(horizontal: false, vertical: true)
            }

            switch state {
            case .idle:
                EmptyView()
            case .loading:
                loadingBody
            case .loaded(_, let substitution):
                resultCard(for: substitution)
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
            Text("Finding a substitute…")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Finding a substitute")
    }

    /// The suggestion, in a burnt-orange-accented elevated card.
    private func resultCard(for substitution: IngredientSubstitution) -> some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Label {
                Text(substitution.substitute)
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.label)
            } icon: {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(DODColor.accent)
            }

            Text(substitution.note)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DODSpacing.md)
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Graceful empty result — the model ran but had nothing, or was
    /// unavailable at call time.
    private var notFoundBody: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("No substitute found")
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
            Text("We couldn't suggest a substitute for this one. Try another ingredient.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DODSpacing.md)
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
    }
}

#Preview("Substitution — loaded") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SubstitutionSheet(
            state: .loaded(ingredient: "1 cup buttermilk", substitution: .cannedButtermilk),
            onDone: {}
        )
    }
}

#Preview("Substitution — loading") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SubstitutionSheet(state: .loading(ingredient: "1 cup buttermilk"), onDone: {})
    }
}

#Preview("Substitution — not found") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SubstitutionSheet(state: .notFound(ingredient: "unobtanium"), onDone: {})
    }
}
