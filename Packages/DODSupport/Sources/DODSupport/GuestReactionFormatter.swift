import Foundation

/// DUT-981 — builds the public WordPress comment body for a guest's
/// in-person praise captured after a cookout. Pure so it is unit-testable.
public enum GuestReactionFormatter {

    /// Max characters of the guest's quote kept in the body.
    public static let maxQuoteLength = 500

    /// Returns nil when the quote or guest name is blank after trimming.
    /// Otherwise: `“<quote>” — <guest>, at a cookout hosted by <host>`.
    /// The host clause is omitted when `hostName` is blank.
    public static func commentBody(quote: String, guestName: String, hostName: String) -> String? {
        let trimmedQuote = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGuestName = guestName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHostName = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuote.isEmpty, !trimmedGuestName.isEmpty else { return nil }
        let clipped = String(trimmedQuote.prefix(maxQuoteLength))
        var line = "\u{201C}\(clipped)\u{201D} \u{2014} \(trimmedGuestName)"
        if !trimmedHostName.isEmpty { line += ", at a cookout hosted by \(trimmedHostName)" }
        return line
    }
}
