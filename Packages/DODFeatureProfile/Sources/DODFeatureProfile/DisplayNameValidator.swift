import Foundation

/// DUT-415 — on-device validation of a profile **Display Name**: it must not be
/// blank, and must not contain vulgar/crass language or impersonate notorious
/// bad actors (criminals, abusers, perpetrators of atrocities).
///
/// Privacy-first: everything is local (a bundled, reviewable blocklist) — no
/// name ever leaves the device. The check is intentionally a *deterrent*, not a
/// guarantee: a blocklist is inherently incomplete and is meant to be expanded
/// over time. Inputs are normalized first so common evasions (leetspeak, spacing,
/// diacritics, repeated letters) don't slip past.
public enum DisplayNameValidation: Equatable, Sendable {
    /// Blank or whitespace-only (or nothing left after stripping punctuation).
    case empty
    /// Matched the vulgar/impersonation blocklist.
    case inappropriate
    /// Acceptable.
    case ok
}

public enum DisplayNameValidator {

    /// Validate a raw, user-entered display name.
    public static func validate(_ raw: String) -> DisplayNameValidation {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        let normalized = normalize(trimmed)
        // All punctuation / non-letters (e.g. "...", "🙂") leaves nothing to show.
        guard !normalized.isEmpty else { return .empty }

        // 1. Substring blocklist — terms long/unambiguous enough that a substring
        //    match rarely catches an innocent name (run against the normalized,
        //    spacing/leet-stripped form so "f.u_c k" and "phuck" are caught).
        for term in Self.blockedSubstrings where normalized.contains(term) {
            return .inappropriate
        }

        // 2. Barred figures — match the normalized full string against notorious
        //    names (also substring, since "iamhitler" should still match).
        for figure in Self.blockedFigures where normalized.contains(figure) {
            return .inappropriate
        }

        // 3. Whole-word blocklist — short terms that WOULD false-positive as a
        //    substring (the "Scunthorpe problem": Cassandra, Dick, Hancock...).
        //    Matched only as a standalone normalized token.
        let tokens = Set(
            trimmed.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .map(normalize)
                .filter { !$0.isEmpty }
        )
        if !tokens.isDisjoint(with: Self.blockedWholeWords) {
            return .inappropriate
        }

        return .ok
    }

    // MARK: - Normalization

    /// Lowercase, fold diacritics, de-leetspeak, drop non-letters, and collapse
    /// 3+ repeated letters to two — so "Ⓗɇllⓞ", "h e l l o", and "heeeello"
    /// converge, defeating the most common filter-evasion tricks.
    static func normalize(_ input: String) -> String {
        let folded = input.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let deLeet = String(folded.map { Self.leetMap[$0] ?? $0 })
        let lettersOnly = deLeet.filter { $0.isLetter }
        return collapseRuns(lettersOnly)
    }

    /// Collapse any run of 3+ identical letters down to two (keeps real doubles
    /// like "ll" intact while killing "fuuuuck" / "niiice"-style padding).
    private static func collapseRuns(_ input: String) -> String {
        var out = ""
        var last: Character?
        var runLen = 0
        for ch in input {
            if ch == last {
                runLen += 1
                if runLen <= 2 { out.append(ch) }
            } else {
                out.append(ch)
                last = ch
                runLen = 1
            }
        }
        return out
    }

    private static let leetMap: [Character: Character] = [
        "0": "o", "1": "i", "!": "i", "3": "e", "4": "a", "@": "a",
        "5": "s", "$": "s", "7": "t", "8": "b", "9": "g", "2": "z",
    ]

    // MARK: - Blocklists
    //
    // Curated starter lists — deliberately conservative and easy to extend.
    // Stored normalized (lowercase, de-leet, letters-only) so they compare
    // directly against `normalize(_:)` output.

    /// Vulgar/crass terms safe to match as a substring (long/unambiguous).
    static let blockedSubstrings: Set<String> = [
        "fuck", "shit", "bitch", "bastard", "asshole", "dickhead", "bullshit",
        "motherfucker", "cunt", "whore", "slut", "pussy", "wank",
        "jackoff", "jerkoff", "blowjob", "handjob", "dildo", "boner",
        "nigger", "nigga", "faggot", "retard",
        "tranny", "pedo", "pedophile", "rapist", "molester", "nazi",
    ].map(normalize).reduce(into: Set<String>()) { $0.insert($1) }

    /// Short terms matched only as a whole token (avoid Scunthorpe false-positives
    /// like Hancock/Babcock/Hitchcock, Spicer/Spice, Enrique's nickname "Kike").
    static let blockedWholeWords: Set<String> = [
        "ass", "cum", "tit", "tits", "twat", "fag", "jizz", "damn",
        "cock", "spic", "chink", "kike",
    ].map(normalize).reduce(into: Set<String>()) { $0.insert($1) }

    /// Notorious figures (genocide/atrocity perpetrators, terrorists, infamous
    /// serial killers + child abusers). Normalized; matched as a substring so
    /// "imhitler" still trips. Starter list — expand as needed.
    static let blockedFigures: Set<String> = [
        "adolfhitler", "hitler", "josefstalin", "stalin", "polpot",
        "benitomussolini", "mussolini", "osamabinladen", "binladen",
        "saddamhussein", "idiamin", "slobodanmilosevic", "heinrichhimmler",
        "josefmengele", "tednundy", "tedbundy", "jeffreydahmer", "dahmer",
        "johnwaynegacy", "jimmysavile", "jeffreyepstein", "epstein",
        "haroldshipman", "arielcastro", "richardramirez", "andreichikatilo",
    ].map(normalize).reduce(into: Set<String>()) { $0.insert($1) }
}
