import DODDesignSystem
import DODIntelligence
import SwiftUI

/// v2 on-device AI — the ingredient-substitution sheet.
///
/// Flow: the user picks a **reason** (or "No Specific Reason") so the swap fits
/// the need, taps **Suggest a Substitute** to run the on-device model, then
/// **Apply** to replace the shopping-list row with the suggestion. Renders
/// ``ShoppingListViewModel/SubstitutionState``: `.pickingReason` shows the reason
/// chips, `.loading` a spinner, `.loaded` the suggestion in a
/// ``DODColor/surfaceElevated`` card with an Apply toolbar action, `.notFound`
/// a graceful empty result.
///
/// Copy conventions (CL-305): Title Case controls/headings, sentence-case body,
/// no em dashes. Dismiss is a top-left Cancel; the top-right confirmation action
/// is Apply and appears only once a suggestion is loaded.
struct SubstitutionSheet: View {

    let state: ShoppingListViewModel.SubstitutionState
    /// Run the model for the current ingredient with the picked reason.
    let onSuggest: (SubstitutionReason?) -> Void
    /// Replace the row with the loaded suggestion.
    let onApply: () -> Void
    /// Dismiss without applying.
    let onCancel: () -> Void

    @State private var selectedReason: SubstitutionReason?

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
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onCancel() }
                            .accessibilityIdentifier("shopping-substitution-cancel")
                    }
                    if case .loaded = state {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Apply") { onApply() }
                                .tint(DODColor.accent)
                                .accessibilityIdentifier("shopping-substitution-apply")
                        }
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
            case .pickingReason:
                reasonPicker
            case .loading:
                loadingBody
            case .loaded(_, _, let substitution):
                resultCard(for: substitution)
            case .notFound:
                notFoundBody
            }

            Spacer(minLength: 0)
        }
        .padding(DODSpacing.lg)
    }

    /// Reason chips + the Suggest button (the first step, before any model run).
    private var reasonPicker: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            Text("Why swap it?")
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DODSpacing.xs) {
                    reasonChip(title: "No Specific Reason", reason: nil)
                    ForEach(SubstitutionReason.allCases) { reason in
                        reasonChip(title: reason.title, reason: reason)
                    }
                }
                .padding(.vertical, DODSpacing.xxs)
            }
            .accessibilityIdentifier("shopping-substitution-reasons")

            Button {
                onSuggest(selectedReason)
            } label: {
                Text("Suggest a Substitute")
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.labelOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DODSpacing.sm)
                    .background(Capsule().fill(DODColor.accent))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("shopping-substitution-suggest")
        }
    }

    /// One selectable reason chip; `nil` is the "No Specific Reason" default.
    private func reasonChip(title: String, reason: SubstitutionReason?) -> some View {
        let isSelected = selectedReason == reason
        return Button {
            selectedReason = reason
        } label: {
            Text(title)
                .dodFont(DODType.caption)
                .lineLimit(1)
                .padding(.horizontal, DODSpacing.sm)
                .padding(.vertical, DODSpacing.xs)
                .foregroundStyle(isSelected ? DODColor.labelOnAccent : DODColor.label)
                .background(Capsule().fill(isSelected ? DODColor.accent : DODColor.surfaceElevated))
        }
        .buttonStyle(.plain)
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

    /// The suggestion, in a burnt-orange-accented elevated card. Apply lives in
    /// the toolbar.
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

#Preview("Substitution — pick reason") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SubstitutionSheet(
            state: .pickingReason(itemID: UUID(), ingredient: "1 cup buttermilk"),
            onSuggest: { _ in },
            onApply: {},
            onCancel: {}
        )
    }
}

#Preview("Substitution — loaded") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SubstitutionSheet(
            state: .loaded(itemID: UUID(), ingredient: "1 cup buttermilk", substitution: .cannedButtermilk),
            onSuggest: { _ in },
            onApply: {},
            onCancel: {}
        )
    }
}
