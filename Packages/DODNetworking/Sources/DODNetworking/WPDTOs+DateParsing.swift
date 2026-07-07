import Foundation

extension WPDTO {

    /// Precomputed ISO8601 formatters, tried in order. `formatOptions` was the
    /// only per-call mutation in the old `parseWPDate`, so both variants are
    /// built once as shared statics (DUT-693) rather than allocating a fresh
    /// formatter and mutating its options on every call.
    ///
    /// `nonisolated(unsafe)`: `ISO8601DateFormatter` isn't `Sendable`, but these
    /// are configured once at init and thereafter used read-only — every caller
    /// only invokes `date(from:)`, never mutates `formatOptions` — so concurrent
    /// parsing is safe. (Mutating a shared formatter's options at call time would
    /// NOT be, which is exactly why both variants are precomputed.)
    nonisolated(unsafe) private static let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let internetDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Parse a WP ISO8601 `date`. DUT-398: append "Z" only when the stamp lacks
    /// its own offset (doing so blindly niled "…+00:00"/fractional stamps → `now`).
    static func parseWPDate(_ raw: String?) -> Date {
        guard let raw else { return Date() }
        let withZone = hasExplicitOffset(raw) ? raw : raw + "Z"
        for formatter in [fractionalDateFormatter, internetDateFormatter] {
            if let date = formatter.date(from: withZone) { return date }
        }
        return Date()
    }

    /// True when `raw` carries a timezone ("Z" or a "+HH:MM"/"-HHMM" time offset).
    private static func hasExplicitOffset(_ raw: String) -> Bool {
        if raw.hasSuffix("Z") { return true }
        guard let tIndex = raw.lastIndex(of: "T") else { return false }
        let time = raw[raw.index(after: tIndex)...]
        guard let sign = time.lastIndex(where: { $0 == "+" || $0 == "-" }) else { return false }
        let digits = time[sign...].dropFirst().filter { $0 != ":" }
        return (digits.count == 2 || digits.count == 4) && digits.allSatisfy(\.isNumber)
    }
}
