import Foundation

// MARK: - Value-type voice model (AVFoundation-free)
//
// US-40 / AC-40.9 (T-720; amended by CL-279 / DUT-329) — the Cook Mode Voice
// Mode quality-selection engine. A deliberately AVFoundation-free projection of
// the selection-relevant attributes of an `AVSpeechSynthesisVoice`, so the
// selection algorithm (``VoiceSelector``) runs under `swift test` on the
// package's macOS slice with zero real-audio dependency (CL-79 / CL-109).
// `SystemSpeechSynthesizer` builds `[VoiceDescriptor]` from the live
// `AVSpeechSynthesisVoice.speechVoices()` catalog and feeds it to the selector.
//
// CL-279 (DUT-329) — Cook Mode uses ONE voice: the best installed for the
// device language. There is no in-app voice or gender choice (the gender picker
// + the per-voice picker were removed); voices are managed only in the iOS
// Settings app. So selection carries no user preference — it is purely
// "natural-first, highest quality".

/// The synthesis quality tier of a voice. `default` is the basic concatenative
/// ("robotic") tier that `AVSpeechSynthesisVoice(language:)` returns; `enhanced`
/// + `premium` are the natural-sounding neural tiers. Ordered so
/// `premium > enhanced > .default` for "pick the best" sorting.
public enum VoiceQuality: Int, Sendable, Comparable {
    case `default` = 0
    case enhanced = 1
    case premium = 2

    public static func < (lhs: VoiceQuality, rhs: VoiceQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Value projection of an `AVSpeechSynthesisVoice`'s selection-relevant
/// attributes. Built from the live catalog by `SystemSpeechSynthesizer`;
/// consumed by ``VoiceSelector``.
public struct VoiceDescriptor: Sendable, Equatable {
    /// The voice's stable identifier — what `AVSpeechSynthesisVoice(identifier:)`
    /// resolves back to a real voice.
    public let identifier: String
    /// BCP-47 language tag (e.g. `en-US`).
    public let languageCode: String
    public let quality: VoiceQuality

    public init(identifier: String, languageCode: String, quality: VoiceQuality) {
        self.identifier = identifier
        self.languageCode = languageCode
        self.quality = quality
    }
}

// MARK: - Selection algorithm

/// Picks the best installed voice for a language: **natural-first, highest
/// quality**. Among voices matching the requested language, any natural
/// (`enhanced` / `premium`) voice outranks every robotic (`default`/compact)
/// one, the highest quality tier wins, and ties break to an exact language-tag
/// match, then **Samantha** (DUT-330 — the out-of-box default voice), then the
/// stable identifier.
///
/// US-40 / AC-40.9 (T-720); CL-279 / DUT-329 — no user preference (one
/// auto-selected voice; voices are managed only in the iOS Settings app);
/// CL-280 / DUT-330 — Samantha is the default voice (a tie-break *below* quality,
/// so a downloaded natural voice still wins, keeping the DUT-327 robot fix).
///
/// Returns `nil` when no voice matches the language at all, in which case the
/// caller falls back to the system default — so a locale with no installed
/// voices degrades exactly as before, never worse.
public enum VoiceSelector {

    /// - Parameters:
    ///   - available: the installed voice catalog (value projection).
    ///   - languageCode: BCP-47 tag or bare language code; matched by language
    ///     *family* prefix (`"en"` matches `en-US` / `en-GB`); `nil` matches
    ///     every voice. An exact tag match is preferred as a tie-break.
    /// - Returns: the chosen voice's identifier, or `nil` if no language match.
    public static func bestVoiceIdentifier(
        from available: [VoiceDescriptor],
        languageCode: String?
    ) -> String? {
        let matches = available.filter {
            matchesLanguage($0.languageCode, languageCode) && isUsable($0)
        }
        guard !matches.isEmpty else { return nil }
        let best = matches.min { lhs, rhs in
            sortKey(for: lhs, languageCode: languageCode) < sortKey(for: rhs, languageCode: languageCode)
        }
        return best?.identifier
    }

    /// The highest synthesis-quality tier installed for a language. Drives the
    /// "is anything natural installed?" check behind the Settings + Cook Mode
    /// "install a better voice" prompts (T-722).
    public static func bestAvailableQuality(
        forLanguage languageCode: String?,
        from available: [VoiceDescriptor]
    ) -> VoiceQuality? {
        available
            .filter { matchesLanguage($0.languageCode, languageCode) && isUsable($0) }
            .map(\.quality)
            .max()
    }

    /// Whether a natural-sounding (`.enhanced` or `.premium`) voice is installed
    /// for the language. `false` means only the compact (robotic) tier is
    /// installed — the cue the "install a better voice" prompts gate on. A
    /// `nil` quality (no voice at all) also returns `false`.
    public static func hasNaturalVoice(
        forLanguage languageCode: String?,
        in available: [VoiceDescriptor]
    ) -> Bool {
        guard let best = bestAvailableQuality(forLanguage: languageCode, from: available) else {
            return false
        }
        return best > .default
    }

    // MARK: - Private

    /// DUT-331 — Siri voices (identifier `com.apple.ttsbundle.siri_*`) appear in
    /// `AVSpeechSynthesisVoice.speechVoices()` and report enhanced/premium
    /// quality, AND `AVSpeechSynthesisVoice(identifier:)` resolves them — but
    /// `AVSpeechSynthesizer` silently refuses to *speak* with a Siri voice in a
    /// third-party app and falls back to the compact default, so it sounds
    /// robotic. Worse, because they report a high quality tier, natural-first
    /// selection would prefer an unusable Siri voice over a genuinely usable
    /// downloaded Enhanced/Premium one. Exclude them everywhere — selection AND
    /// the "is a natural voice installed?" gate — so we only ever consider voices
    /// the app can actually speak with. Matched by the `ttsbundle.siri` marker;
    /// regular voices are `com.apple.voice.{compact,enhanced,premium}.*` (kept).
    private static func isUsable(_ voice: VoiceDescriptor) -> Bool {
        !voice.identifier.localizedCaseInsensitiveContains("ttsbundle.siri")
    }

    /// DUT-330 — the default voice name. Apple ships the classic en-US voice
    /// "Samantha" on every device, and its `AVSpeechSynthesisVoice.identifier`
    /// contains "Samantha" (e.g. `com.apple.voice.compact.en-US.Samantha`), so a
    /// case-insensitive identifier match reaches it across the compact / enhanced
    /// / premium variants.
    private static let defaultVoiceName = "Samantha"

    /// A comparable sort key. Lower sorts first (more preferred).
    ///   - naturalRank: 0 = natural (enhanced/premium), 1 = robotic (default).
    ///   - qualityRank: 0 = premium, 1 = enhanced, 2 = default (best first).
    ///   - exactLocaleRank: 0 = exact language-tag match, 1 = prefix-only.
    ///   - samanthaRank: 0 = Samantha, 1 = anything else. DUT-330 — makes the
    ///     out-of-box voice Samantha rather than whatever sorts first by
    ///     identifier (Albert / a novelty voice). Only a tie-break **below**
    ///     quality: a natural voice still beats a compact Samantha, so a
    ///     downloaded better voice is still used (the DUT-327 robot fix holds).
    ///   - identifier: final stable tie-break so selection is deterministic.
    private static func sortKey(for voice: VoiceDescriptor, languageCode: String?) -> SortKey {
        let naturalRank = voice.quality > .default ? 0 : 1
        let qualityRank = 2 - voice.quality.rawValue  // premium(2) → 0
        let isExactLocale =
            languageCode.map {
                voice.languageCode.caseInsensitiveCompare($0) == .orderedSame
            } ?? false
        let isSamantha = voice.identifier.localizedCaseInsensitiveContains(defaultVoiceName)
        return SortKey(
            natural: naturalRank,
            quality: qualityRank,
            exactLocale: isExactLocale ? 0 : 1,
            samantha: isSamantha ? 0 : 1,
            identifier: voice.identifier
        )
    }

    /// Prefix-aware, case-insensitive language match. `nil` request matches
    /// everything. `"en"` matches `"en-US"`; `"en-US"` matches `"en-US"` but not
    /// `"en-GB"` for the exact-tie-break, yet both share the `"en"` family.
    private static func matchesLanguage(_ voiceLang: String, _ request: String?) -> Bool {
        guard let request, !request.isEmpty else { return true }
        return languageFamily(voiceLang).caseInsensitiveCompare(languageFamily(request)) == .orderedSame
    }

    /// The primary language subtag — everything before the first `-`.
    private static func languageFamily(_ tag: String) -> String {
        if let dash = tag.firstIndex(of: "-") { return String(tag[..<dash]) }
        return tag
    }

    private struct SortKey: Comparable {
        let natural: Int
        let quality: Int
        let exactLocale: Int
        let samantha: Int
        let identifier: String

        static func < (lhs: SortKey, rhs: SortKey) -> Bool {
            if lhs.natural != rhs.natural { return lhs.natural < rhs.natural }
            if lhs.quality != rhs.quality { return lhs.quality < rhs.quality }
            if lhs.exactLocale != rhs.exactLocale { return lhs.exactLocale < rhs.exactLocale }
            if lhs.samantha != rhs.samantha { return lhs.samantha < rhs.samantha }
            return lhs.identifier < rhs.identifier
        }
    }
}
