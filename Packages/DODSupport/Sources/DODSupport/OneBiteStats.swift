import Foundation

/// DUT-996 — pure progress numbers over `[DinerReactionEntry]`.
public enum OneBiteStats {

    /// Distinct recipes `dinerKey` tried or liked in the calendar month of `now`.
    public static func newThingsTried(
        dinerKey: String,
        in entries: [DinerReactionEntry],
        asOf now: Date,
        calendar: Calendar = .current
    ) -> Int {
        let ids =
            entries
            .filter {
                $0.dinerKey == dinerKey
                    && $0.reaction.countsAsTried
                    && calendar.isDate($0.loggedAt, equalTo: now, toGranularity: .month)
            }
            .map(\.recipeID)
        return Set(ids).count
    }

    /// "Jake's tried 4 new things this month." nil when the count is 0, so
    /// the UI shows nothing rather than a discouraging zero.
    public static func monthlyHeadline(
        dinerKey: String,
        dinerName: String,
        in entries: [DinerReactionEntry],
        asOf now: Date,
        calendar: Calendar = .current
    ) -> String? {
        let newThingsCount = newThingsTried(dinerKey: dinerKey, in: entries, asOf: now, calendar: calendar)
        guard newThingsCount > 0 else { return nil }
        return "\(dinerName)'s tried \(newThingsCount) new \(newThingsCount == 1 ? "thing" : "things") this month."
    }
}
