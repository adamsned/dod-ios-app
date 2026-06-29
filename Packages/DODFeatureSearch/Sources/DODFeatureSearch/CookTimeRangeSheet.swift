import DODDesignSystem
import SwiftUI

/// CL-122 / REG-31 (T-644) — the Apple-Timer-style two-wheel min/max
/// range picker for the Search-page cook-time chip. Half-sheet (`.medium`
/// detent) presentation with the two `Picker.pickerStyle(.wheel)` views
/// side by side: left wheel is **Min**, right wheel is **Max**. Each
/// wheel's first entry is `"Any"` (= nil bound for that side) followed
/// by a curated duration list. Selection is buffered on `@State`; the
/// "Apply" button commits the buffered selection back to the caller's
/// `SearchFilters`. Drag-down dismisses without applying (no auto-commit
/// on selection change — Apple Timer's UX pattern).
///
/// Apple-Timer parity rationale (per CL-122): the user asked for the
/// wheel-picker shape verbatim. We keep the snap-on-release-but-no-clamp
/// behavior of the system Timer — if the user picks min > max, `apply()`
/// returns an empty result set and the empty-state UI handles it, with
/// no clamping pulling the wheel out from under the user's finger.
///
/// Inverted-range handling is intentionally silent (see CL-122's
/// considered-and-rejected (b) — snap-on-release clamping was rejected
/// to preserve the wheel-stays-where-you-put-it expectation).
struct CookTimeRangeSheet: View {

    /// The curated duration list shared by both wheels (in seconds).
    /// Spaced 5/10/15/20/30/45 min for the short tail, then 1-2 hr at
    /// 15-min steps, then 2-4 hr at 30-min steps. Covers the natural
    /// cook-time distribution of the dutchovendaddy.com corpus without
    /// overwhelming the wheel.
    static let durationSeconds: [Int] = [
        5 * 60, 10 * 60, 15 * 60, 20 * 60, 30 * 60, 45 * 60,
        60 * 60, 75 * 60, 90 * 60, 120 * 60, 150 * 60, 180 * 60, 240 * 60,
    ]

    /// Sentinel marking the "Any" wheel entry (= nil bound). Picked at
    /// `-1` so it never collides with a real `durationSeconds` value
    /// (durations are positive) and the `Picker` `tag(_:)` round-trip
    /// works with a single `Int` selection type.
    static let anySentinel: Int = -1

    let initialMinSeconds: Int?
    let initialMaxSeconds: Int?
    let onApply: (_ minSeconds: Int?, _ maxSeconds: Int?) -> Void
    let onCancel: () -> Void

    @State private var selectedMin: Int
    @State private var selectedMax: Int

    init(
        initialMinSeconds: Int?,
        initialMaxSeconds: Int?,
        onApply: @escaping (_ minSeconds: Int?, _ maxSeconds: Int?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialMinSeconds = initialMinSeconds
        self.initialMaxSeconds = initialMaxSeconds
        self.onApply = onApply
        self.onCancel = onCancel
        _selectedMin = State(initialValue: initialMinSeconds ?? Self.anySentinel)
        _selectedMax = State(initialValue: initialMaxSeconds ?? Self.anySentinel)
    }

    var body: some View {
        VStack(spacing: DODSpacing.md) {
            header
            wheels
            actionButtons
        }
        .padding(.horizontal, DODSpacing.md)
        .padding(.top, DODSpacing.md)
        // T-646 / CL-124 — tightened from `lg` to `sm`; combined with the
        // new `.height(340)` detent this removes the dead-space tail that
        // made the sheet look like it was floating above the home indicator.
        .padding(.bottom, DODSpacing.sm)
        .background(DODColor.surface)
    }

    // MARK: - Header

    private var header: some View {
        Text("Cook time")
            .dodFont(DODType.heading)
            .foregroundStyle(DODColor.label)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Wheels

    private var wheels: some View {
        HStack(spacing: DODSpacing.md) {
            wheelColumn(
                title: "Min",
                accessibilityLabel: "Minimum cook time",
                selection: $selectedMin
            )
            wheelColumn(
                title: "Max",
                accessibilityLabel: "Maximum cook time",
                selection: $selectedMax,
                accessibilityIdentifier: "dod.search.cookTimeWheelMax"
            )
        }
        // T-646 / CL-124 — was 180; trimmed to 160 to tighten the sheet
        // alongside the new content-fitted detent.
        .frame(maxHeight: 160)
    }

    @ViewBuilder
    private func wheelColumn(
        title: String,
        accessibilityLabel: String,
        selection: Binding<Int>,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        VStack(spacing: DODSpacing.xs) {
            Text(title)
                .dodFont(DODType.caption)
                .foregroundStyle(DODColor.labelSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
            picker(selection: selection)
                .accessibilityLabel(accessibilityLabel)
        }
        .frame(maxWidth: .infinity)
        // T-737 / L5: `.accessibilityIdentifier` on a SwiftUI `Picker(.wheel)`
        // doesn't propagate down to the internal `UIPickerView`-backed
        // `XCUIElementTypePickerWheel`, so XCUITest's
        // `app.pickerWheels.matching(identifier:)` query never resolves the
        // wheel. We host the identifier on the column container and treat
        // it as an accessibility container (`.contain`) so the wheel
        // descendant remains queryable — the test drills into the column
        // and grabs `pickerWheels.firstMatch`.
        .accessibilityElement(children: .contain)
        .modifier(OptionalIdentifierModifier(identifier: accessibilityIdentifier))
    }

    private func picker(selection: Binding<Int>) -> some View {
        let picker = Picker(selection: selection) {
            Text("Any").tag(Self.anySentinel)
            ForEach(Self.durationSeconds, id: \.self) { seconds in
                Text(CookTimeFormatter.label(seconds: seconds)).tag(seconds)
            }
        } label: {
            EmptyView()
        }
        .labelsHidden()
        // `.wheel` is iOS-only; macOS test slice falls back to `.menu`.
        // The wheel-picker UX (the Apple-Timer-style affordance the user
        // asked for verbatim) only matters on iPhone; the macOS build
        // exists so `swift test` can run the L1 suite without requiring
        // a simulator.
        #if os(iOS)
        return picker.pickerStyle(.wheel)
        #else
        return picker
        #endif
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: DODSpacing.xs) {
            Button {
                onApply(
                    selectedMin == Self.anySentinel ? nil : selectedMin,
                    selectedMax == Self.anySentinel ? nil : selectedMax
                )
            } label: {
                Text("Apply")
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.cream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DODSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DODRadius.standard, style: .continuous)
                            .fill(DODColor.castIronBrown)
                    )
            }
            .accessibilityLabel("Apply cook time filter")

            Button {
                selectedMin = Self.anySentinel
                selectedMax = Self.anySentinel
            } label: {
                Text("Reset")
                    .dodFont(DODType.caption)
                    .foregroundStyle(DODColor.labelSecondary)
                    .padding(.vertical, DODSpacing.xxs)
            }
            .accessibilityLabel("Reset cook time filter")
        }
    }
}

/// Helper modifier — `.accessibilityIdentifier(_:)` doesn't take an
/// optional, so we conditionally apply it via this tiny wrapper. Keeps
/// the picker call site declarative without branching the view.
private struct OptionalIdentifierModifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
