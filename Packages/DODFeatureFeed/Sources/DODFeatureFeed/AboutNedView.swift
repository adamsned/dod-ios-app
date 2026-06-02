import DODDesignSystem
import SwiftUI

/// Destination for the About Dutch Oven Daddy row.
///
/// T-738 / CL-134 (2026-05-31, DUT-14) graduated this from the original
/// T-550 "Coming soon — fetched from /about-me/" placeholder to the
/// embedded DUT-14 copy + Ned's photo bundled as a local asset. T-552
/// (the planned WP REST `/about-me/` fetch path) is superseded — the
/// copy is now embedded verbatim, not fetched dynamically. See CL-133
/// for the supersession reasoning + the original magazine-sidebar trade.
///
/// Layout: vertically-stacked centered hero — `VStack(alignment:
/// .center)` with a 160pt image centered horizontally on top, clipped to
/// a `RoundedRectangle(cornerRadius: DODSpacing.sm)` (matching the rest
/// of the app's thumbnail register per `RecipeCard`'s hero treatment),
/// and the verbatim copy below it at full width (leading-aligned). T-741
/// / CL-135 (DUT-18) revised this from the original T-738 magazine
/// sidebar (`HStack(alignment: .top)`, 120pt leading image + paragraph
/// wrapping right) because the right-side wrap did not read well on the
/// live build — DUT-14 explicitly named the centered-above arrangement as
/// the fallback. The image bumps 120pt → 160pt now that it no longer
/// shares the row with the paragraph.
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
        VStack(alignment: .center, spacing: DODSpacing.md) {
            Image("AboutNed")
                .resizable()
                .scaledToFill()
                .frame(width: 160, height: 160)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: DODSpacing.sm,
                        style: .continuous
                    )
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityHidden(true)

            Text(Self.aboutNedCopy)
                .dodFont(DODType.body)
                .foregroundStyle(DODColor.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

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
