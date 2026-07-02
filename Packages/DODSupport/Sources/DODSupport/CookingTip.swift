import Foundation

/// Curated short Dutch-oven cooking tips for the `.accessoryInline` lock-screen
/// widget (DUT-454). Kept SHORT on purpose — the inline slot shares one line
/// with the clock/date, so long text truncates. A pure daily rotation lets the
/// widget show a fresh tip each day with no app-side data bridge (unlike the
/// Latest/Saved widgets, which read App Group snapshots).
public enum CookingTip {

    /// The tip pool. Punchy (~≤30 chars) so each fits the inline slot beside a
    /// small SF Symbol.
    public static let all: [String] = [
        "Preheat the lid for browning",
        "2 top coals per inch of oven",
        "Rotate the oven each check",
        "Rest meat before slicing",
        "Season iron after each wash",
        "Ring your coals for baking",
        "Lift the lid less, hold heat",
        "A dry lid crisps the top",
        "Salt early, taste often",
        "Deglaze for a richer sauce",
        "Low and slow usually wins",
        "Parchment means easy cleanup",
    ]

    /// Deterministic tip for a given day — rotates by absolute day number so the
    /// tip changes daily and is stable within a day (WidgetKit builds a 14-day
    /// timeline so the rotation runs without any app reloads). `calendar` is
    /// injectable so the L1 suite can pin the rotation.
    public static func tip(for date: Date, calendar: Calendar = .current) -> String {
        guard !all.isEmpty else { return "" }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }
}
