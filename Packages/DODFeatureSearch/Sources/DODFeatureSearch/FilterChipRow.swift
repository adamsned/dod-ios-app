import DODDesignSystem
import DODDomain
import SwiftUI

// MARK: - Filter chips

/// Horizontal row of filter chips above the results list. Each chip flips
/// one slice of `SearchFilters`; mutating the binding triggers
/// `SearchViewModel`'s `reapplyFilters` and the result set re-ranks
/// instantly without a network call (US-12 / AC-12.3).
///
/// Extracted from `SearchView.swift` to its own file (DUT-527) so both stay
/// under SwiftLint's 400-line `file_length` cap — same split rationale as
/// `IdleSuggestionsView` / `FlowLayout`. No dependency on `SearchView`'s source.
struct FilterChipRow: View {
    @Binding var filters: SearchFilters
    /// CL-122 (T-644): the chip is a `Button` that opens the wheel-picker
    /// half-sheet instead of the pre-T-644 inline `Menu`. The sheet is
    /// presented from the row so the chip itself stays a one-liner.
    @State private var cookTimeSheetPresented: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DODSpacing.xs) {
                cookTimeChip
            }
            .padding(.horizontal, DODSpacing.md)
            .padding(.bottom, DODSpacing.sm)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search filters")
        // CL-122 (T-644): half-sheet hosting the two-wheel min/max picker.
        // Drag-down dismisses without applying (no auto-commit on
        // selection change — Apple-Timer pattern). The sheet's "Apply"
        // button writes the committed selection back into `$filters`.
        .sheet(isPresented: $cookTimeSheetPresented) {
            CookTimeRangeSheet(
                initialMinSeconds: filters.cookTimeMinSeconds,
                initialMaxSeconds: filters.cookTimeMaxSeconds,
                onApply: { newMin, newMax in
                    filters.cookTimeMinSeconds = newMin
                    filters.cookTimeMaxSeconds = newMax
                    cookTimeSheetPresented = false
                },
                onCancel: { cookTimeSheetPresented = false }
            )
            // T-646 / CL-124 — content-fitted custom detent (was `.medium`
            // which left a tall dead-space tail above the home indicator).
            // 340pt comfortably hosts header + wheels (160) + Apply + Reset
            // + reduced bottom padding + the home-indicator safe area.
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
            // T-645 / CL-123 — fill the system sheet chrome with the
            // brand surface color so the brown (dark) / white (light)
            // panel reaches the bottom of the screen instead of letting
            // the default chrome blur show through the safe-area gap.
            .presentationBackground(DODColor.surface)
        }
    }

    // US-29 / AC-29.4 / CL-49.4 + CL-105 (T-636): the "All categories"
    // filter chip was removed because the Categories tab (bottom nav)
    // already serves as the canonical "browse all categories" surface,
    // making the chip duplicative. `filters.categoryID` is retained on
    // the model (always nil here → "all categories" pipeline path) so
    // the search merge logic remains untouched; only the UI affordance
    // to mutate it is gone.

    private var cookTimeChip: some View {
        let label = cookTimeChipLabel(
            min: filters.cookTimeMinSeconds,
            max: filters.cookTimeMaxSeconds
        )
        return Button {
            cookTimeSheetPresented = true
        } label: {
            chipLabel(
                text: label,
                systemImage: "clock",
                isOn: filters.hasCookTimeRange
            )
        }
        .accessibilityLabel("Cook time filter, \(label)")
        // DUT-526 — the chip conveys active/inactive purely by fill color.
        // Expose the state to VoiceOver + non-color users: the selected trait
        // (announced as "selected") plus an explicit On/Off value.
        .accessibilityAddTraits(filters.hasCookTimeRange ? .isSelected : [])
        .accessibilityValue(filters.hasCookTimeRange ? "On" : "Off")
        // T-638 / CL-107 — stable test handle for the L5 E2E
        // `test_search_chip_row_hidden_on_idle` (negative-asserts the chip is
        // not queryable on the idle Search tab — pins CL-106 part 1's
        // `viewModel.state != .idle` gate) and `test_search_cook_time_filter_narrows_results`
        // (taps the chip → opens the wheel sheet → picks max → asserts the
        // filtered result count narrows via the hydration path — pins
        // CL-106 part 2 + REG-21 + REG-31).
        .accessibilityIdentifier("dod.search.cookTimeChip")
    }

    // US-33 / CL-105 (T-636): the "Recently viewed" toggle chip was
    // removed because the Recent searches section in
    // `IdleSuggestionsView` already surfaces a user's recent activity,
    // making the toggle duplicative. `filters.recentlyViewedOnly` is
    // retained on the model (defaults to false → no-op filter) so the
    // search pipeline stays unchanged; only the UI to mutate it is gone.

    private func chipLabel(text: String, systemImage: String, isOn: Bool) -> some View {
        HStack(spacing: DODSpacing.xxs) {
            Image(systemName: systemImage)
            Text(text).lineLimit(1)
        }
        .dodFont(DODType.caption)
        .foregroundStyle(isOn ? DODColor.cream : DODColor.label)
        .padding(.horizontal, DODSpacing.sm)
        .padding(.vertical, DODSpacing.xxs)
        // DUT-526 — the visual chip is short; guarantee a 44pt tap target so
        // the hit area meets the a11y minimum (the audit tool needs a real
        // frame, not just `contentShape`).
        .frame(minHeight: 44)
        .background(
            Capsule().fill(isOn ? DODColor.castIronBrown : DODColor.surfaceElevated)
        )
        .contentShape(Rectangle())
    }
}
