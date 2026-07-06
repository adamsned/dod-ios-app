import DODDesignSystem
import SwiftUI

/// Shared "Published <absolute date>" caption for the article + recipe detail
/// headers. Renders a long-style, locale-aware date — "Published June 1, 2026"
/// — in the secondary-caption style both surfaces use.
///
/// T-789 / CL-185 (DUT-96): introduced when the published date was added to
/// recipe detail (Ned's open question on DUT-95) and the format moved from
/// medium ("Jun 1, 2026", DUT-95 / T-788) to long ("June 1, 2026") per Ned's
/// preference — so both surfaces share one format + style. The formatter
/// previously lived privately in ``ArticleDetailView``.
struct PublishedDateCaption: View {

    let date: Date

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        // DUT-623: the incoming `date` is a `date_gmt` UTC instant. Format it in
        // UTC so the shown calendar day matches the publication day. Without a
        // pinned time zone the formatter uses the device's local zone, which
        // shifts a near-midnight UTC instant back a day for users west of GMT
        // (e.g. a "June 1 00:30 UTC" post shows "May 31" in US time zones).
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    var body: some View {
        Text("Published \(Self.formatter.string(from: date))")
            .dodFont(DODType.caption)
            .foregroundStyle(DODColor.labelSecondary)
    }
}
