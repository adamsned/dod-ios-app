import Foundation

extension CookoutGroup {
    /// e.g. "Sunday cookout — 4 dishes, fed 10" or "Saturday cookout — 2 dishes".
    public func headline(fed: Int? = nil, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = "EEEE"
        let weekday = formatter.string(from: day)
        let dishes = "\(dishCount) dish\(dishCount == 1 ? "" : "es")"
        var text = "\(weekday) cookout — \(dishes)"
        if let fed, fed > 0 { text += ", fed \(fed)" }
        return text
    }
}
