import Foundation

public enum CookLogConfig {
    public static let userDefaultsKey = "dod.widget.cookLog.v1"
    /// Keep ~1 year of events so the file stays tiny.
    public static let retentionDays = 366
}
