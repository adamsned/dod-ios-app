import DODDesignSystem
import SwiftUI

/// One aisle-grouped shopping-list row (US-39 / AC-39.5), extracted from
/// ``ShoppingListView`` (DUT-693 PR2 — perf).
///
/// **Why its own `View`:** the row takes a plain `checked` Bool + toggle /
/// already-have closures instead of reading `viewModel.isChecked(item)` inline
/// in the parent body. That keeps `ShoppingListView.body` from subscribing to
/// `checkedIDs`, so checking a row off no longer re-runs the parent body — the
/// aisle `sections` regroup (`Dictionary(grouping:)`), the `visibleItems`
/// refilter, and both toolbars stop recomputing on every toggle. SwiftUI diffs
/// each row on its `checked` input, so a toggle re-renders only the one row that
/// changed.
///
/// **Trailing controls (v2 on-device AI):** the leading circle checks a row off
/// (strikethrough, row stays); the trailing side carries two visible icon
/// buttons — a **trash** that removes the row ("I already have this",
/// `onMarkAlreadyHave`) and, when the on-device model is usable, a **wand**
/// (`onSubstitute`) that starts an Apple-Intelligence ingredient swap. The wand
/// sits at the far trailing edge, opposite the leading check-off. The old
/// swipe-to-substitute / swipe-to-already-have actions are replaced by these
/// always-visible buttons so the AI swap is discoverable at a glance.
struct ShoppingListRow: View {

    let item: ShoppingListViewModel.Item
    /// This row's checked state, passed in (not read from the view model here)
    /// so the parent body stays free of the `checkedIDs` dependency.
    let checked: Bool
    /// Flip this row's AC-39.5 check-off state.
    let onToggle: () -> Void
    /// AC-39.5 / CL-82 — "I already have this": the trailing trash button removes
    /// the row.
    let onMarkAlreadyHave: () -> Void
    /// v2 on-device AI — whether the "Substitute" affordance is offered on this
    /// row. `false` on unsupported devices (no usable model), which hides the
    /// wand button + its custom accessibility action entirely (no dead control).
    let showSubstitute: Bool
    /// v2 on-device AI — start an ingredient substitution for this row.
    let onSubstitute: () -> Void

    init(
        item: ShoppingListViewModel.Item,
        checked: Bool,
        onToggle: @escaping () -> Void,
        onMarkAlreadyHave: @escaping () -> Void,
        showSubstitute: Bool = false,
        onSubstitute: @escaping () -> Void = {}
    ) {
        self.item = item
        self.checked = checked
        self.onToggle = onToggle
        self.onMarkAlreadyHave = onMarkAlreadyHave
        self.showSubstitute = showSubstitute
        self.onSubstitute = onSubstitute
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DODSpacing.sm) {
            Button {
                onToggle()
            } label: {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(checked ? DODColor.accent : DODColor.labelSecondary)
                    // DUT-527 — SF-Symbol-only toggle; guarantee a 44pt tap target.
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("shopping-list-row-toggle")
            .accessibilityLabel(ShoppingListView.checkOffLabel(checked: checked))

            VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                Text(item.ingredientText)
                    .dodFont(DODType.body)
                    .strikethrough(checked)
                    .foregroundStyle(checked ? DODColor.labelSecondary : DODColor.label)
                Text(item.recipeTitle)
                    .dodFont(DODType.caption)
                    .strikethrough(checked)
                    .foregroundStyle(DODColor.labelSecondary)
            }

            Spacer(minLength: 0)

            // CL-82 — "I already have this" is now a visible trash button (was a
            // trailing swipe); removes the row.
            trailingIconButton(
                systemImage: "trash",
                tint: DODColor.labelSecondary,
                identifier: "shopping-already-have-action",
                label: "I already have this",
                action: onMarkAlreadyHave
            )

            // v2 on-device AI — the always-visible wand starts the AI swap, at
            // the far trailing edge (opposite the leading check-off). Hidden
            // entirely when the model can't run.
            if showSubstitute {
                trailingIconButton(
                    systemImage: "wand.and.stars",
                    tint: DODColor.accent,
                    identifier: "shopping-substitute-action",
                    label: "Substitute with Apple Intelligence",
                    action: onSubstitute
                )
            }
        }
        .padding(.vertical, DODSpacing.xxs)
        .listRowBackground(DODColor.surfaceElevated)
        .contentShape(Rectangle())
        // DUT-693 — check-off delight, keyed to THIS row's own `checked` so the
        // parent body stays free of the `checkedIDs` dependency.
        .sensoryFeedback(.selection, trigger: checked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(checked ? .isSelected : [])
        // DUT-483 / AC-39.11 — `.accessibilityElement(.ignore)` collapses the row
        // and swallows the icon buttons, so re-expose each interaction as a
        // custom action for VoiceOver.
        .accessibilityAction(named: ShoppingListView.checkOffLabel(checked: checked)) {
            onToggle()
        }
        .accessibilityActions {
            Button("I Already Have This") { onMarkAlreadyHave() }
                .accessibilityIdentifier("shopping-already-have-action")
            if showSubstitute {
                Button("Suggest Substitute") { onSubstitute() }
                    .accessibilityIdentifier("shopping-substitute-action")
            }
        }
    }

    /// A 44pt trailing icon button (trash / wand) with a plain style and its own
    /// VoiceOver label + identifier.
    private func trailingIconButton(
        systemImage: String,
        tint: Color,
        identifier: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
    }

    /// AC-39.11 — `"<ingredient text>, <aisle>, from <recipe title>"`.
    private var accessibilityLabel: String {
        "\(item.ingredientText), \(AisleHeader.displayName(item.aisle)), from \(item.recipeTitle)"
    }
}
