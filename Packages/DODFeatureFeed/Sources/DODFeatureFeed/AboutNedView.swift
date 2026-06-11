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
/// Layout: vertically-stacked centered hero inside a `ScrollView` —
/// `VStack(alignment: .center)` with a 160pt image centered horizontally
/// on top, clipped to a `Circle()` (T-749 / CL-146 — matching the app's
/// avatar register per AC-44.15; was a `RoundedRectangle` pre-T-749), and
/// the verbatim copy below it at full width (leading-aligned) as a
/// leading-aligned `VStack` of paragraph `Text`s. T-741 / CL-135 (DUT-18)
/// revised this from the original T-738 magazine sidebar
/// (`HStack(alignment: .top)`, 120pt leading image + paragraph wrapping
/// right) because the right-side wrap did not read well on the live build
/// — DUT-14 explicitly named the centered-above arrangement as the
/// fallback. The image bumps 120pt → 160pt now that it no longer shares
/// the row with the paragraph.
///
/// **T-749 / CL-146 (DUT-55) — `ScrollView` + multi-paragraph story.**
/// The intro paragraph gained three story paragraphs below it; the
/// content is now wrapped in a `ScrollView` so the longer copy + the
/// 160pt photo don't clip on shorter devices (the pre-T-749 plain
/// top-aligned `VStack` + `Spacer` would clip the tail on an iPhone SE).
///
/// Lives in its own file (not inline in `SettingsView.swift`) so the
/// host file stays under the 400-line `file_length` cap. The view is
/// only consumed from one call site (`SettingsView`'s About
/// `NavigationLink`), so module-internal visibility is sufficient.
struct AboutNedView: View {

    /// The verbatim DUT-14 About Ned intro copy. Pinned by an L1 test
    /// (`aboutNedView_copy_matchesDUT14Verbatim`) so any future paraphrase
    /// trips CI — surfacing the change to the spec author before it
    /// silently lands on the user's device.
    static let aboutNedCopy: String =
        "Hi I'm Ned, the Dutch Oven Daddy! I'm a full-time computer nerd and part-time cook. My passion is cast iron cooking with tips, tricks, and delicious recipes. I love using my recipes to bring together family and friends. I believe everything is made better in cast iron!"

    /// T-749 / CL-146 (DUT-55) — the three story paragraphs that render
    /// below the intro, in order, with a paragraph break between each.
    /// Verbatim per Spencer's DUT-55 copy; pinned by an L1 test
    /// (`aboutNedView_storyParagraphs_matchVerbatim`) on the same
    /// no-silent-paraphrase contract as ``aboutNedCopy``.
    static let aboutNedStoryParagraphs: [String] = [
        "Dutch Oven Daddy is the happy result of a gifted cast iron skillet and meal prep for a family member recovering from surgery. The desire to keep track of the recipes created brought Dutch Oven Daddy into existence. As these things go, the randomness of the Internet allowed D.O.D. to flourish as did with my love and appreciation for cast iron.",
        "Since that first skillet, my activity in the cast iron community has grown. I love to educate others on not only how to cook with it, but how to care for it along with the benefits of using cast iron.",
        "Dutch Oven Daddy not only develops online content but also has had multiple television appearances and taught many cast iron focused classes. I love everything about the multi-generational durability of cast iron.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: DODSpacing.md) {
                Image("AboutNed")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DODSpacing.md) {
                    paragraphText(Self.aboutNedCopy)
                    ForEach(Self.aboutNedStoryParagraphs, id: \.self) { paragraph in
                        paragraphText(paragraph)
                    }
                }
            }
            .padding(DODSpacing.md)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(DODColor.surface)
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("settings-about")
    }

    /// A single body paragraph in the brand body register, full-width +
    /// leading-aligned, allowed to grow vertically to fit its wrapped
    /// content. Extracted so the intro + each story paragraph share one
    /// modifier chain (T-749 / CL-146).
    @ViewBuilder
    private func paragraphText(_ text: String) -> some View {
        Text(text)
            .dodFont(DODType.body)
            .foregroundStyle(DODColor.label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
