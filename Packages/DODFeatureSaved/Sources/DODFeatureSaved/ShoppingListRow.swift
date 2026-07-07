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
/// changed. Visuals are byte-identical to the former inline `row(for:)`.
struct ShoppingListRow: View {

    let item: ShoppingListViewModel.Item
    /// This row's checked state, passed in (not read from the view model here)
    /// so the parent body stays free of the `checkedIDs` dependency.
    let checked: Bool
    /// Flip this row's AC-39.5 check-off state.
    let onToggle: () -> Void
    /// AC-39.5 / CL-82 — mark "I already have this" (trailing swipe removes the row).
    let onMarkAlreadyHave: () -> Void

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
            // DUT-231 — the leading circle CHECKS a row off (strikethrough,
            // row stays visible); it is NOT the "already have" affordance (that
            // is the trailing swipe → `markAlreadyHave`, which removes the row).
            // Label it for its real behavior and reflect the current state, so
            // VoiceOver users can tell check-off from swipe-to-remove.
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
        }
        .padding(.vertical, DODSpacing.xxs)
        .listRowBackground(DODColor.surfaceElevated)
        .contentShape(Rectangle())
        // DUT-693 — check-off delight. Keyed to THIS row's own `checked` (not
        // `viewModel.checkedIDs`) so the haptic fires on the tap that flips this
        // row while keeping the parent body free of the `checkedIDs` dependency
        // the row extraction removed — a list-level `trigger: checkedIDs` would
        // re-subscribe the parent and undo the regroup-on-toggle saving.
        .sensoryFeedback(.selection, trigger: checked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(checked ? .isSelected : [])
        // DUT-483 / AC-39.11 — `.accessibilityElement(.ignore)` collapses the
        // row and swallows the leading check-toggle Button, and the trailing
        // swipe action REMOVES the row (markAlreadyHave). Without this a
        // VoiceOver shopper has no way to check a row off — their only action
        // deletes it. Re-expose the core AC-39.5 check-off as a custom action.
        // DUT-231 — this action mirrors the leading toggle (check-off, not
        // "already have"), so it uses the same state-reflecting Check/Uncheck
        // wording; "already have" stays reserved for the trailing swipe.
        .accessibilityAction(named: ShoppingListView.checkOffLabel(checked: checked)) {
            onToggle()
        }
        // AC-39.5 / CL-82 — the trailing "I already have this" affordance.
        .swipeActions(edge: .trailing) {
            Button {
                onMarkAlreadyHave()
            } label: {
                Label("I already have this", systemImage: "checkmark.circle")
            }
            .tint(DODColor.accent)
        }
    }

    /// AC-39.11 — `"<ingredient text>, <aisle>, from <recipe title>"`.
    private var accessibilityLabel: String {
        "\(item.ingredientText), \(AisleHeader.displayName(item.aisle)), from \(item.recipeTitle)"
    }
}
