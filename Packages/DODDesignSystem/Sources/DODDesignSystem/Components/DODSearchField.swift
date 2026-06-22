import SwiftUI

/// Brand search field — `DODColor.surfaceElevated` background filled into a
/// `Capsule(style: .continuous)` shape with a leading `magnifyingglass`
/// glyph, a `TextField` body, and an optional trailing clear button.
///
/// Adopted by T-648 / CL-126 / REG-32 to unify the app's search-bar visual
/// language. Originally two call sites (Search + the Categories tab); since
/// T-800 (CL-194) folded the Categories tab into Search, the sole remaining
/// call site is:
///
/// 1. `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift`
///    (replaces the inline `searchField` `HStack`-with-`RoundedRectangle`).
///
/// Public API: `init(text:placeholder:onClear:onFocusChange:)`.
/// When `onClear` is `nil`, the clear button just empties the bound text;
/// the Search tab supplies `{ viewModel.clear() }` so the clear button
/// preserves the full view-model-side cleanup (state, items, lastQuery,
/// debounce cancel) instead of only clearing the query string.
/// `onFocusChange` (T-779 / DUT-85) reports keyboard focus gain/loss so a
/// call site can react — the Search tab commits a recent search on dismissal;
/// `nil` (Categories) is a no-op.
///
/// Per-surface stable accessibility identifiers (e.g. `dod.search.field.search`,
/// `dod.search.field.categories`) are added at the call site rather than on
/// the component itself, so a single component can serve multiple surfaces
/// without identifier collisions.
public struct DODSearchField: View {

    @Binding public var text: String
    public let placeholder: String
    public let onClear: (() -> Void)?
    /// T-779 / DUT-85 — keyboard-focus reporter (gain `true` / loss `false`).
    /// `nil` is a no-op, so existing call sites (Categories) are unaffected.
    public let onFocusChange: ((Bool) -> Void)?
    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String,
        onClear: (() -> Void)? = nil,
        onFocusChange: ((Bool) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onClear = onClear
        self.onFocusChange = onFocusChange
    }

    public var body: some View {
        HStack(spacing: DODSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DODColor.labelSecondary)
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .focused($isFocused)
            if !text.isEmpty {
                Button {
                    if let onClear {
                        onClear()
                    } else {
                        text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DODColor.labelSecondary)
                }
                .accessibilityLabel("Clear")
            }
        }
        .padding(.vertical, DODSpacing.sm)
        .padding(.horizontal, DODSpacing.md)
        .background(
            Capsule(style: .continuous)
                .fill(DODColor.surfaceElevated)
        )
        // T-843 / DUT-261 — the `surfaceDivider` stroke is dropped: it rendered
        // as an ugly orange outline on the light surface (tester-reported). The
        // fill + a slightly stronger soft shadow keep the field defined (Search
        // and Categories both) without the outline.
        .shadow(color: DODColor.charcoal.opacity(0.12), radius: 4, x: 0, y: 1)
        .onChange(of: isFocused) { _, focused in
            onFocusChange?(focused)
        }
    }
}

#Preview("Empty") {
    DODSearchField(text: .constant(""), placeholder: "Search recipes")
        .padding()
        .background(DODColor.surface)
}

#Preview("With text") {
    DODSearchField(text: .constant("chicken"), placeholder: "Search recipes")
        .padding()
        .background(DODColor.surface)
}
