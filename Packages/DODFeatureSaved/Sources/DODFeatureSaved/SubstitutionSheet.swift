import DODDesignSystem
import DODIntelligence
import SwiftUI

/// v2 on-device AI — the ingredient-substitution sheet.
///
/// Flow: the user picks a **reason** (or "No Specific Reason") so the swap fits
/// the need, taps **Suggest a Substitute** to run the on-device model, then acts
/// on the ``SubstitutionResult`` — **Apply** a chosen option, **Leave It Out**,
/// or just read a "not a good fit" explanation and close.
///
/// Safety framing (US-54 follow-up):
/// - a short general AI disclaimer is visible at all times below the Suggest
///   button and below any result;
/// - selecting Allergy or Sensitivity raises a second, more detailed allergen
///   disclaimer before the model runs;
/// - an Allergy result gets a prominent red safety banner and a stronger haptic
///   than an ordinary swap.
///
/// The result rendering (options / omit / not-a-good-fit + the allergy banner)
/// lives in `SubstitutionSheet+Result.swift` to keep this file under the
/// SwiftLint 400-line cap. Copy conventions (CL-305): Title Case
/// controls/headings, sentence-case body, no em dashes.
struct SubstitutionSheet: View {

    let state: ShoppingListViewModel.SubstitutionState
    /// Run the model for the current ingredient with the picked reason.
    let onSuggest: (SubstitutionReason?) -> Void
    /// Replace the row with a chosen substitute option.
    let onApply: (IngredientSubstitution) -> Void
    /// Leave the ingredient out (the "omit" verdict's action) — removes the row.
    let onOmit: () -> Void
    /// Dismiss without changing anything.
    let onCancel: () -> Void

    @State private var selectedReason: SubstitutionReason?
    /// Which option the user has picked from an `.options` result (best-first, so
    /// it defaults to the first). Clamped at apply time in case a re-generate
    /// returned fewer options.
    @State private var selectedOptionIndex = 0

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
                    confirmationToolbarItem
                }
                // Stronger haptic for an allergy result than for an ordinary swap.
                .sensoryFeedback(trigger: isLoaded) { wasLoaded, nowLoaded in
                    guard !wasLoaded, nowLoaded else { return nil }
                    return state.reason?.isAllergy == true ? .warning : .success
                }
        }
        .accessibilityIdentifier("shopping-substitution-sheet")
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
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
                case .loaded(_, _, _, let result):
                    resultBody(for: result)
                case .notFound:
                    notFoundBody
                }
            }
            .padding(DODSpacing.lg)
        }
    }

    /// The trailing confirmation action, which depends on the loaded verdict:
    /// Apply a chosen option, Leave It Out for an omit result, or nothing (a
    /// not-a-good-fit result is informational — the user just cancels).
    @ToolbarContentBuilder
    private var confirmationToolbarItem: some ToolbarContent {
        if case .loaded(_, _, _, let result) = state {
            switch result.verdict {
            case .options(let options):
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply(options) }
                        .tint(DODColor.accent)
                        .accessibilityIdentifier("shopping-substitution-apply")
                }
            case .omit:
                ToolbarItem(placement: .confirmationAction) {
                    Button("Leave It Out") { onOmit() }
                        .tint(DODColor.accent)
                        .accessibilityIdentifier("shopping-substitution-omit")
                }
            case .notAGoodFit:
                ToolbarItem(placement: .confirmationAction) { EmptyView() }
            }
        }
    }

    /// Apply the selected option, clamping the index in case a re-generate
    /// returned fewer options than were shown when the user last tapped.
    private func apply(_ options: [IngredientSubstitution]) {
        guard !options.isEmpty else { return }
        let index = options.indices.contains(selectedOptionIndex) ? selectedOptionIndex : 0
        onApply(options[index])
    }

    // MARK: - Reason picker (first step)

    /// Reason chips + the Suggest button + the always-on general disclaimer, plus
    /// the expanded allergen disclaimer once Allergy or Sensitivity is picked.
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

            // req: a short, highly visible disclaimer below the button at all times.
            generalDisclaimer

            // req: selecting an allergy or intolerance raises a second, more
            // detailed disclaimer before the model runs.
            if selectedReason?.requiresAllergenWarning == true {
                expandedAllergenDisclaimer
            }
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

    // MARK: - Loading / not-found

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

    /// Graceful empty result — the model ran but had nothing, or was unavailable
    /// at call time.
    private var notFoundBody: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Text("No substitute found")
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
            Text("We couldn't suggest a substitute for this one. Try another ingredient.")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
            generalDisclaimer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DODSpacing.md)
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
    }

    // MARK: - Disclaimers

    /// The always-on general AI disclaimer (req 5). Shown below the Suggest
    /// button and below any result.
    var generalDisclaimer: some View {
        Label {
            Text(
                "AI suggestions can be wrong. Double-check any substitution before you cook, especially amounts and dietary needs."
            )
            .dodFont(DODType.caption)
            .foregroundStyle(DODColor.labelSecondary)
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(DODColor.labelSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// The expanded allergen disclaimer (req 6), shown once Allergy or
    /// Sensitivity is selected. More detailed and more prominent than the
    /// general one.
    private var expandedAllergenDisclaimer: some View {
        VStack(alignment: .leading, spacing: DODSpacing.xs) {
            Label {
                Text("Allergies and intolerances")
                    .dodFont(DODType.bodyEmphasized)
                    .foregroundStyle(DODColor.warning)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DODColor.warning)
            }
            Text(
                "Do not rely on AI for allergy or intolerance decisions. Always verify the actual ingredient and its allergen information yourself. Hidden sources and cross-contamination are common."
            )
            .dodFont(DODType.body)
            .foregroundStyle(DODColor.label)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DODSpacing.md)
        .background(DODColor.warning.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                .strokeBorder(DODColor.warning.opacity(0.5), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("shopping-substitution-allergen-disclaimer")
    }

    // MARK: - Derived

    private var isLoaded: Bool {
        if case .loaded = state { return true }
        return false
    }

    /// Binding-free read of the picked option index for the result view.
    var optionSelection: Int { selectedOptionIndex }

    /// Set the picked option (called from the result view's option rows).
    func selectOption(_ index: Int) { selectedOptionIndex = index }
}

#Preview("Substitution — pick reason") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SubstitutionSheet(
            state: .pickingReason(itemID: UUID(), ingredient: "1 cup buttermilk"),
            onSuggest: { _ in },
            onApply: { _ in },
            onOmit: {},
            onCancel: {}
        )
    }
}

#Preview("Substitution — options") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SubstitutionSheet(
            state: .loaded(
                itemID: UUID(),
                ingredient: "1 cup buttermilk",
                reason: .dairyFree,
                result: .cannedButtermilkOptions
            ),
            onSuggest: { _ in },
            onApply: { _ in },
            onOmit: {},
            onCancel: {}
        )
    }
}
