import DODDesignSystem
import DODSupport
import SwiftUI
import WidgetKit

/// "Cooking Tip" — a fresh short Dutch-oven cooking tip each day. Ships in three
/// sizes from one widget: `.accessoryInline` (lock screen, beside the clock —
/// DUT-454) and `.systemSmall` + `.systemMedium` home-screen cards (DUT-459).
/// No App Group read — the tip is a pure daily rotation
/// (``CookingTip/tip(for:calendar:)``), so the provider builds a 14-day timeline
/// and iOS rotates the tip on its own with no app reloads.
///
/// Tap opens the app to `dod://tip/<index>`, which shows the FULL tip in a
/// dialog (DUT-457 — the inline slot truncates it).
///
/// Spec trace: US-22 (inline); DUT-454, DUT-457, DUT-459.
struct CookingTipWidget: Widget {

    // Kind preserved from the DUT-454 inline-only widget so existing installs
    // keep their widget identity.
    static let kind = "com.dutchovendaddy.DODApp.Widget.CookingTipInline"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CookingTipProvider()) { entry in
            CookingTipEntryView(entry: entry)
        }
        .configurationDisplayName("Cooking Tip")
        .description("A short Dutch oven cooking tip each day.")
        .supportedFamilies([.accessoryInline, .systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

/// One entry per day: the day's tip + its rotation `index` (carried in the tap
/// deep link so the app can show the full tip — DUT-457).
struct CookingTipEntry: TimelineEntry {
    let date: Date
    let tip: String
    let index: Int
}

/// Builds a 14-day timeline of daily tips so the rotation runs without any
/// app-side reloads (the tip is a pure function of the day).
struct CookingTipProvider: TimelineProvider {

    private func entry(for date: Date, _ calendar: Calendar = .current) -> CookingTipEntry {
        CookingTipEntry(
            date: date,
            tip: CookingTip.tip(for: date, calendar: calendar),
            index: CookingTip.index(for: date, calendar: calendar)
        )
    }

    func placeholder(in context: Context) -> CookingTipEntry { entry(for: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (CookingTipEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CookingTipEntry>) -> Void) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        var entries: [CookingTipEntry] = []
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                continue
            }
            entries.append(entry(for: day, calendar))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

/// Renders the tip per family: inline is a one-line flame + text; the home-screen
/// small/medium sizes use the design-system ``WidgetCard/TipCard``. All tap to
/// `dod://tip/<index>` (DUT-457).
struct CookingTipEntryView: View {

    @Environment(\.widgetFamily) private var family
    let entry: CookingTipEntry

    var body: some View {
        content
            .widgetURL(URL(string: "dod://tip/\(entry.index)"))
            .accessibilityLabel("Cooking tip: \(entry.tip)")
            .containerBackground(for: .widget) {
                // Inline is text-only over the system background; the home-screen
                // cards paint on the (tint-aware) surface.
                if family == .accessoryInline {
                    Color.clear
                } else {
                    DODColor.surface
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .systemMedium:
            WidgetCard.TipCard(tip: entry.tip, isCompact: false)
        case .systemSmall:
            WidgetCard.TipCard(tip: entry.tip, isCompact: true)
        default:
            Label(entry.tip, systemImage: "flame.fill")
        }
    }
}
