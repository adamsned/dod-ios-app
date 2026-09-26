import DODDesignSystem
import SwiftUI

/// The About Dutch Oven Daddy destination (Settings ▸ About Dutch Oven Daddy).
///
/// DUT-1330 (2026-09-26) rebuilt this as a full translation of the website
/// About page (`dutchovendaddy.com/about-me/`) in the app's design language,
/// for v1 + v2. A full-bleed hero photo (Ned holding the No. 8 lid) leads,
/// then: the About story, Fun Facts, Publications (+ podcasts), Television
/// Appearances (photo cards), Events, and FAQ. Skips the site's "Navigating
/// My Site", "My Top Recipes", "Keep in Touch", and Subscribe / sidebar
/// blocks per spec. External references (podcasts, articles, TV-segment
/// recipes) open in the browser.
///
/// History: graduated from the T-550 "Coming soon" placeholder → T-738 /
/// CL-134 (DUT-14) embedded intro + circular avatar → T-749 / CL-146 (DUT-55)
/// added the three story paragraphs → this DUT-1330 full-page build. The
/// intro (``aboutNedCopy``) and story (``aboutNedStoryParagraphs``) copy stays
/// verbatim and L1-pinned; the section content lives in ``AboutNedContent``.
///
/// Section builders live in `AboutNedView+Sections.swift` so this file stays
/// under the 400-line `file_length` cap.
struct AboutNedView: View {

    @Environment(\.openURL) var openURL

    /// The verbatim DUT-14 intro, kept as a warm lead above the site's story
    /// paragraphs. Pinned by `aboutNedView_copy_matchesDUT14Verbatim`.
    static let aboutNedCopy: String =
        "Hi I'm Ned, the Dutch Oven Daddy! I'm a full-time computer nerd and part-time cook. My passion is cast iron cooking with tips, tricks, and delicious recipes. I love using my recipes to bring together family and friends. I believe everything is made better in cast iron!"

    /// The three verbatim story paragraphs (DUT-55), matching the website's
    /// "About Ned Adams & Dutch Oven Daddy" section. Pinned by
    /// `aboutNedView_storyParagraphs_matchVerbatim`.
    static let aboutNedStoryParagraphs: [String] = [
        "Dutch Oven Daddy is the happy result of a gifted cast iron skillet and meal prep for a family member recovering from surgery. The desire to keep track of the recipes created brought Dutch Oven Daddy into existence. As these things go, the randomness of the Internet allowed D.O.D. to flourish as did with my love and appreciation for cast iron.",
        "Since that first skillet, my activity in the cast iron community has grown. I love to educate others on not only how to cook with it, but how to care for it along with the benefits of using cast iron.",
        "Dutch Oven Daddy not only develops online content but also has had multiple television appearances and taught many cast iron focused classes. I love everything about the multi-generational durability of cast iron.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroImage
                VStack(alignment: .leading, spacing: DODSpacing.xl) {
                    aboutSection
                    funFactsSection
                    publicationsSection
                    televisionSection
                    eventsSection
                    faqSection
                }
                .padding(.horizontal, DODSpacing.md)
                .padding(.top, DODSpacing.lg)
                .padding(.bottom, DODSpacing.xl)
            }
        }
        .background(DODColor.surface)
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("settings-about")
    }

    // MARK: - Hero + About story

    /// Full-bleed hero: Ned holding up the vintage Wagner Ware No. 8 lid.
    private var heroImage: some View {
        Image("AboutHero")
            .resizable()
            .scaledToFill()
            .frame(height: 260)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityLabel("Ned Adams, the Dutch Oven Daddy, holding a cast iron Dutch oven lid")
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            sectionHeader("About Dutch Oven Daddy")
            Text(Self.aboutNedCopy)
                .dodFont(DODType.bodyEmphasized)
                .foregroundStyle(DODColor.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Self.aboutNedStoryParagraphs, id: \.self) { paragraph($0) }
        }
    }

    // MARK: - Shared building blocks (used here + in +Sections)

    /// A section heading in the brand heading register.
    @ViewBuilder
    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .dodFont(DODType.heading)
            .foregroundStyle(DODColor.labelStrong)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A plain body paragraph, full-width + leading-aligned.
    @ViewBuilder
    func paragraph(_ text: String) -> some View {
        Text(text)
            .dodFont(DODType.body)
            .foregroundStyle(DODColor.label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A body paragraph that renders inline markdown links (`[text](url)`),
    /// tinted burnt-orange and opening in the browser on tap. Falls back to
    /// plain text if the markdown can't be parsed.
    @ViewBuilder
    func richParagraph(_ markdown: String) -> some View {
        richText(markdown)
            .dodFont(DODType.body)
            .foregroundStyle(DODColor.label)
            .tint(DODColor.burntOrange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Runtime-string markdown → `Text`. Uses `AttributedString(markdown:)`
    /// (reliable for non-literal strings, unlike `LocalizedStringKey`) so the
    /// inline links survive; whitespace is preserved and only inline syntax
    /// is interpreted (no block/list transforms).
    func richText(_ markdown: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(markdown)
    }
}
