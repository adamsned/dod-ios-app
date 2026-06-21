import DODDesignSystem
import SwiftUI

/// T-822 — the Grid/List recipe-layout picker shown in Settings ▸
/// Customization. Moved here from the Feed + Search toolbar toggles; it binds
/// the shared `RecipeListLayout` `@AppStorage` that `FeedView` / `SearchView`
/// read, so this one control drives the layout on both tabs. A standalone
/// `View` (like `VoiceRows`) so `SettingsView` stays under the file-length cap.
struct LayoutSettingPicker: View {

    @AppStorage(RecipeListLayout.storageKey) private var layoutRaw =
        RecipeListLayout.gallery.rawValue

    var body: some View {
        Picker(selection: layoutBinding) {
            ForEach(RecipeListLayout.allCases, id: \.self) { value in
                Text(value.displayName)
                    .tag(value)
            }
        } label: {
            Text("Recipe Layout")
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
        }
        .accessibilityIdentifier("settings-picker-layout")
    }

    private var layoutBinding: Binding<RecipeListLayout> {
        Binding(
            get: { RecipeListLayout(rawValue: layoutRaw) ?? .gallery },
            set: { layoutRaw = $0.rawValue }
        )
    }
}
