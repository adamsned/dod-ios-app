import DODDesignSystem
import SwiftUI

/// DUT-1330 — the About page's translated sections + their photo cards and
/// link rows. Split out of `AboutNedView.swift` to keep that file under the
/// 400-line `file_length` cap. Content is sourced from ``AboutNedContent``.
extension AboutNedView {

    // MARK: - Fun Facts about Me

    var funFactsSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            sectionHeader("Fun Facts about Me")
            VStack(alignment: .leading, spacing: DODSpacing.sm) {
                ForEach(AboutNedContent.funFacts, id: \.self) { fact in
                    HStack(alignment: .top, spacing: DODSpacing.sm) {
                        Text("•")
                            .dodFont(DODType.bodyEmphasized)
                            .foregroundStyle(DODColor.burntOrange)
                        richParagraph(fact)
                    }
                }
            }
        }
    }

    // MARK: - Publications (+ podcasts)

    var publicationsSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            sectionHeader("Publications")
            ForEach(AboutNedContent.publicationParagraphs, id: \.self) { richParagraph($0) }
            paragraph(AboutNedContent.podcastsIntro)
            VStack(spacing: DODSpacing.xs) {
                ForEach(AboutNedContent.podcasts) { linkRow($0) }
            }
        }
    }

    // MARK: - Television Appearances

    var televisionSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            sectionHeader("Television Appearances")
            VStack(spacing: DODSpacing.md) {
                ForEach(AboutNedContent.televisionAppearances) { mediaCard($0) }
            }
        }
    }

    // MARK: - Events

    var eventsSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            sectionHeader("Events")
            VStack(spacing: DODSpacing.md) {
                ForEach(AboutNedContent.events) { mediaCard($0) }
            }
        }
    }

    // MARK: - FAQ

    var faqSection: some View {
        VStack(alignment: .leading, spacing: DODSpacing.md) {
            sectionHeader("Frequently Asked Questions")
            VStack(alignment: .leading, spacing: DODSpacing.md) {
                ForEach(AboutNedContent.faqs) { faq in
                    VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                        Text(faq.question)
                            .dodFont(DODType.bodyEmphasized)
                            .foregroundStyle(DODColor.labelStrong)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        paragraph(faq.answer)
                    }
                }
            }
        }
    }

    // MARK: - Reusable rows / cards

    /// A tappable external-link row (podcasts): title + date, burnt-orange
    /// out-arrow, on a `surfaceElevated` capsule-radius card.
    @ViewBuilder
    func linkRow(_ item: AboutNedContent.LinkRow) -> some View {
        Button {
            if let url = item.url { openURL(url) }
        } label: {
            HStack(spacing: DODSpacing.sm) {
                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    Text(item.title)
                        .dodFont(DODType.bodyEmphasized)
                        .foregroundStyle(DODColor.label)
                    Text(item.detail)
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DODColor.burntOrange)
            }
            .padding(DODSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DODColor.surfaceElevated, in: RoundedRectangle(cornerRadius: DODRadius.standard))
        }
        .buttonStyle(.plain)
        .accessibilityHint(item.url == nil ? "" : "Opens in the browser")
    }

    /// A photo card for a TV segment or event: full-width image, then the
    /// title + source · date. Tappable (opens the recipe in the browser)
    /// when the feature carries a URL; a plain card otherwise.
    @ViewBuilder
    func mediaCard(_ item: AboutNedContent.MediaFeature) -> some View {
        if let url = item.url {
            Button {
                openURL(url)
            } label: {
                mediaCardBody(item, tappable: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the recipe in the browser")
        } else {
            mediaCardBody(item, tappable: false)
        }
    }

    @ViewBuilder
    private func mediaCardBody(_ item: AboutNedContent.MediaFeature, tappable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(item.imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .accessibilityHidden(true)
            HStack(alignment: .top, spacing: DODSpacing.sm) {
                VStack(alignment: .leading, spacing: DODSpacing.xxs) {
                    Text(item.title)
                        .dodFont(DODType.bodyEmphasized)
                        .foregroundStyle(DODColor.label)
                    Text(mediaSubtitle(item))
                        .dodFont(DODType.caption)
                        .foregroundStyle(DODColor.labelSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if tappable {
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DODColor.burntOrange)
                }
            }
            .padding(DODSpacing.sm)
        }
        .background(DODColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DODRadius.standard))
    }

    /// "Show · Date", or just the date for events with no broadcaster.
    private func mediaSubtitle(_ item: AboutNedContent.MediaFeature) -> String {
        item.source.isEmpty ? item.date : "\(item.source) · \(item.date)"
    }
}
