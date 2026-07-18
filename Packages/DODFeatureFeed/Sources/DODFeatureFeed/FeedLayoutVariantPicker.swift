import DODDesignSystem
import SwiftUI

/// US-43 Phase b/c/d (T-711..T-713) — the Classic/Magazine layout-variant picker
/// shown in Settings ▸ Customization, directly beneath the Grid/List
/// ``LayoutSettingPicker``. Binds the shared ``DODFeed/layoutVariantStorageKey``
/// `@AppStorage` that `FeedView` reads, so this one control flips the whole
/// magazine register (16:9 heroes, editorial cards, the brand masthead, and the
/// numbered "Popular" badge) on or off — letting the classic look return per
/// US-43's "behind-the-flag from Phase b on" reversibility contract.
///
/// A standalone `View` (like ``LayoutSettingPicker``) so `SettingsView` stays
/// under the file-length cap.
struct FeedLayoutVariantPicker: View {

    @AppStorage(DODFeed.layoutVariantStorageKey) private var variantRaw =
        DODFeed.LayoutVariant.magazine.rawValue

    var body: some View {
        Picker(selection: variantBinding) {
            ForEach(DODFeed.LayoutVariant.allCases, id: \.self) { value in
                Text(value.displayName)
                    .tag(value)
            }
        } label: {
            Text("Recipe Style")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
        }
        // DUT-551 (CL-306) — brand-orange menu value + chevron, matching the
        // App Appearance + Recipe Layout pickers.
        .tint(DODColor.burntOrange)
        .accessibilityIdentifier("settings-picker-layout-variant")
    }

    private var variantBinding: Binding<DODFeed.LayoutVariant> {
        Binding(
            get: { DODFeed.LayoutVariant(rawValue: variantRaw) ?? .magazine },
            set: { variantRaw = $0.rawValue }
        )
    }
}
