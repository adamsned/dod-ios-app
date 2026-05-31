import SwiftUI

/// Brand search field — `DODColor.surfaceElevated` background filled into a
/// `Capsule(style: .continuous)` shape with a leading `magnifyingglass`
/// glyph, a `TextField` body, and an optional trailing clear button.
///
/// Two call sites — both adopted by T-648 / CL-126 / REG-32 so the Search
/// tab and the Categories tab share a single search-bar visual language:
///
/// 1. `Packages/DODFeatureSearch/Sources/DODFeatureSearch/SearchView.swift`
///    (replaces the inline `searchField` `HStack`-with-`RoundedRectangle`).
/// 2. `Packages/DODFeatureCategories/Sources/DODFeatureCategories/CategoryListView.swift`
///    (replaces the `.searchable(text:placement:.navigationBarDrawer(...))`
///    modifier; the field now sits as a sticky element above the List,
///    which is the deliberate trade for matching Search's visual).
///
/// Public API: `init(text: Binding<String>, placeholder: String, onClear: (() -> Void)? = nil)`.
/// When `onClear` is `nil`, the clear button just empties the bound text;
/// the Search tab supplies `{ viewModel.clear() }` so the clear button
/// preserves the full view-model-side cleanup (state, items, lastQuery,
/// debounce cancel) instead of only clearing the query string.
///
/// Per-surface stable accessibility identifiers (e.g. `dod.search.field.search`,
/// `dod.search.field.categories`) are added at the call site rather than on
/// the component itself, so a single component can serve multiple surfaces
/// without identifier collisions.
public struct DODSearchField: View {

    @Binding public var text: String
    public let placeholder: String
    public let onClear: (() -> Void)?

    public init(
        text: Binding<String>,
        placeholder: String,
        onClear: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onClear = onClear
    }

    public var body: some View {
        HStack(spacing: DODSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DODColor.labelSecondary)
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
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
