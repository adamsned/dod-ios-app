import DODDesignSystem
import SwiftUI

/// Destination for the About Dutch Oven Daddy row.
///
/// T-738 / CL-134 (2026-05-31, DUT-14) graduated this from the original
/// T-550 "Coming soon — fetched from /about-me/" placeholder to the
/// embedded DUT-14 copy + Ned's photo bundled as a local asset. T-552
/// (the planned WP REST `/about-me/` fetch path) is superseded — the
/// copy is now embedded verbatim, not fetched dynamically. See CL-133
/// for the supersession reasoning + the magazine-sidebar layout trade.
///
/// Layout: magazine sidebar — `HStack(alignment: .top)` with a 120pt
/// leading image clipped to a `RoundedRectangle(cornerRadius:
/// DODSpacing.sm)` (matching the rest of the app's thumbnail register
/// per `RecipeCard`'s hero treatment) + the verbatim copy wrapping to
/// its right via `.fixedSize(horizontal: false, vertical: true)`.
///
/// Lives in its own file (not inline in `SettingsView.swift`) so the
/// host file stays under the 400-line `file_length` cap. The view is
/// only consumed from one call site (`SettingsView`'s About
/// `NavigationLink`), so module-internal visibility is sufficient.
struct AboutNedView: View {

    /// The verbatim DUT-14 About Ned copy. Pinned by an L1 test
    /// (`aboutNedView_copy_matchesDUT14Verbatim`) so any future paraphrase
    /// trips CI — surfacing the change to the spec author before it
    /// silently lands on the user's device.
    static let aboutNedCopy: String =
        "Hi I'm Ned, the Dutch Oven Daddy! I'm a full-time computer nerd and part-time cook. My passion is cast iron cooking with tips, tricks, and delicious recipes. I love using my recipes to bring together family and friends. I believe everything is made better in cast iron!"

    var body: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            HStack(alignment: .top, spacing: DODSpacing.md) {
                Image("AboutNed")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: DODSpacing.sm,
                            style: .continuous
                        )
                    )
                    .accessibilityHidden(true)

                Text(Self.aboutNedCopy)
                    .dodFont(DODType.body)
                    .foregroundStyle(DODColor.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DODSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DODColor.surface)
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("settings-about")
    }
}
