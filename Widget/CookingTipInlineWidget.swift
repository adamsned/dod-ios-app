import DODSupport
import SwiftUI
import WidgetKit

/// "Cooking Tip" — `.accessoryInline` lock-screen widget (DUT-454). The inline
/// slot sits beside the clock/date and holds one short line. Unlike the other
/// lock-screen widgets (Latest Recipe = newest content, Saved = a shortcut),
/// this one is purely informational: a fresh, short Dutch-oven cooking tip each
/// day. No App Group read — the tip is a pure daily rotation
/// (``CookingTip/tip(for:calendar:)``), so the provider builds a 14-day
/// timeline and iOS rotates the tip on its own with no app reloads.
///
/// Tap opens the app to the feed (`dod://feed`, already covered by US-9's
/// `WidgetDeepLinkParser` — no new parser case).
///
/// Spec trace: US-22 (amended — inline family shipped here); DUT-454.
struct CookingTipInlineWidget: Widget {

    static let kind = "com.dutchovendaddy.DODApp.Widget.CookingTipInline"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CookingTipInlineProvider()) { entry in
            CookingTipInlineEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    // Inline widgets render text-only over a system-managed
                    // background; the empty closure defers to that behavior.
                    Color.clear
                }
        }
        .configurationDisplayName("Cooking Tip")
        .description("A short Dutch oven cooking tip each day, next to your clock.")
        .supportedFamilies([.accessoryInline])
        .contentMarginsDisabled()
    }
}

/// One entry per day carrying that day's tip.
struct CookingTipEntry: TimelineEntry {
    let date: Date
    let tip: String
}

/// Builds a 14-day timeline of daily tips so the inline rotation runs without
/// any app-side reloads (the tip is a pure function of the day).
struct CookingTipInlineProvider: TimelineProvider {

    func placeholder(in context: Context) -> CookingTipEntry {
        CookingTipEntry(date: Date(), tip: CookingTip.tip(for: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (CookingTipEntry) -> Void) {
        completion(CookingTipEntry(date: Date(), tip: CookingTip.tip(for: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CookingTipEntry>) -> Void) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        var entries: [CookingTipEntry] = []
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                continue
            }
            entries.append(CookingTipEntry(date: day, tip: CookingTip.tip(for: day, calendar: calendar)))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

/// The inline face: a small flame symbol + the day's tip on one line. The
/// system handles inline styling + the monochrome tint pass.
struct CookingTipInlineEntryView: View {

    let entry: CookingTipEntry

    var body: some View {
        Label(entry.tip, systemImage: "flame.fill")
            .widgetURL(URL(string: "dod://feed"))
            .accessibilityLabel("Cooking tip: \(entry.tip)")
    }
}
