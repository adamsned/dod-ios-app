import Foundation

public enum CookLogConfig {
    public static let userDefaultsKey = "dod.widget.cookLog.v1"
    /// Keep ~1 year of events so the file stays tiny.
    public static let retentionDays = 366
}

extension WidgetSnapshotStore {
    public func readCookDates() -> [Date] {
        (defaults.array(forKey: CookLogConfig.userDefaultsKey) as? [Double] ?? [])
            .map { Date(timeIntervalSince1970: $0) }
    }

    /// Appends `date` to the persisted cook log.
    public func recordCook(at date: Date = Date(), calendar: Calendar = .current) {
        var dates = readCookDates()
        dates.append(date)
        defaults.set(dates.map { $0.timeIntervalSince1970 }, forKey: CookLogConfig.userDefaultsKey)
    }
}
