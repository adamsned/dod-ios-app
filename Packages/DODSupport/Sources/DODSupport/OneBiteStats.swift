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
}
