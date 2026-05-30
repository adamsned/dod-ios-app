import Foundation

// MARK: - Value-type voice model (AVFoundation-free)
//
// US-40 / AC-40.9..AC-40.11 (T-720, 2026-05-29) — the Cook Mode Voice Mode
// quality + gender-selection engine. These types are a deliberately
// AVFoundation-free projection of the selection-relevant attributes of an
// `AVSpeechSynthesisVoice`, so the selection algorithm (``VoiceSelector``)
// is exercised under `swift test` on the package's macOS slice with zero
// real-audio dependency — exactly the `SpeechSynthesizing` seam pattern the
// rest of `VoiceReader` already uses (CL-79). `SystemSpeechSynthesizer`
// builds `[VoiceDescriptor]` from the live `AVSpeechSynthesisVoice.speechVoices()`
// catalog and feeds it to the selector; the selector itself never imports
// AVFoundation. CL-109 captures the why.

/// The speaker gender of a synthesized voice. Mirrors
/// `AVSpeechSynthesisVoiceGender` without importing AVFoundation so the
/// selection logic stays testable on the macOS slice.
public enum VoiceGender: Sendable, Equatable {
    case male
    case female
    /// The voice catalog reports no gender (common for older / novelty
    /// voices). Treated as an acceptable fallback — never excluded — so a
    /// great-sounding unspecified voice still beats a robotic gender-matched
    /// compact voice when no gender-matched higher-quality voice exists.
    case unspecified
}

/// The synthesis quality tier of a voice. `default` is the basic
/// concatenative ("robotic") tier that `AVSpeechSynthesisVoice(language:)`
/// returns; `enhanced` + `premium` are the natural-sounding neural tiers.
/// Ordered so `premium > enhanced > .default` for "pick the best" sorting.
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
    /// The voice's stable identifier (e.g.
    /// `com.apple.voice.enhanced.en-US.Samantha`) — what
    /// `AVSpeechSynthesisVoice(identifier:)` resolves back to a real voice.
    public let identifier: String
    /// BCP-47 language tag (e.g. `en-US`).
    public let languageCode: String
    public let gender: VoiceGender
    public let quality: VoiceQuality

    public init(
        identifier: String,
        languageCode: String,
        gender: VoiceGender,
        quality: VoiceQuality
    ) {
        self.identifier = identifier
        self.languageCode = languageCode
        self.gender = gender
        self.quality = quality
    }
}

/// The user's voice preference. v1 carries only the gender choice; the
/// quality preference is implicit ("always the best installed"). Defaults to
/// `.female` to match Apple's own system-default voice (en-US Samantha) so
/// the default experience is unsurprising.
public struct VoicePreference: Sendable, Equatable {
    public var gender: VoiceGender

    public init(gender: VoiceGender = .female) {
        self.gender = gender
    }

    /// The v1 default — female, matching the platform default voice.
    public static let `default` = VoicePreference(gender: .female)
}

// MARK: - Selection algorithm

/// Picks the best available voice for a language + user preference.
///
/// US-40 / AC-40.10 (T-720). The algorithm is **gender-primary,
/// quality-secondary**: among voices matching the requested language, it
/// prefers the user's gender, and within that prefers the highest quality
/// tier. This is the load-bearing fix for the "sounds like a robot"
/// complaint — `AVSpeechSynthesisVoice(language:)` (the prior behavior)
/// returns the *default*-quality (compact) voice for a language even when an
/// `enhanced` Siri voice is already installed; this selector explicitly
/// reaches past the compact tier to the natural one.
///
/// Returns `nil` when no voice matches the language at all, in which case the
/// caller falls back to the system default (the prior behavior) — so a locale
/// with no installed voices degrades exactly as before, never worse.
public enum VoiceSelector {

    /// - Parameters:
    ///   - available: the installed voice catalog (value projection).
    ///   - languageCode: BCP-47 language tag or bare language code to match.
    ///     Matches by language *prefix* so `"en"` matches `en-US` / `en-GB`,
    ///     and `"en-US"` matches `en-US` exactly (exact matches are preferred
    ///     over prefix matches as a tie-break). `nil` matches every voice.
    ///   - preference: the user's gender preference.
    /// - Returns: the chosen voice's identifier, or `nil` if no language match.
    public static func bestVoiceIdentifier(
        from available: [VoiceDescriptor],
        languageCode: String?,
        preference: VoicePreference
    ) -> String? {
        let matches = available.filter { matchesLanguage($0.languageCode, languageCode) }
        guard !matches.isEmpty else { return nil }

        // Sort ascending by (genderRank, qualityRank, exactLocaleRank,
        // identifier) and take the first — i.e. the most-preferred voice.
        let best = matches.min { lhs, rhs in
            let lKey = sortKey(for: lhs, languageCode: languageCode, preference: preference)
            let rKey = sortKey(for: rhs, languageCode: languageCode, preference: preference)
            return lKey < rKey
        }
        return best?.identifier
    }

    // MARK: - Private

    /// A comparable sort key. Lower sorts first (more preferred).
    ///   - genderRank: 0 = matches preferred gender, 1 = unspecified
    ///     (acceptable fallback), 2 = opposite gender.
    ///   - qualityRank: 0 = premium, 1 = enhanced, 2 = default (best first).
    ///   - exactLocaleRank: 0 = exact language-tag match, 1 = prefix-only.
    ///   - identifier: final stable tie-break so selection is deterministic.
    private static func sortKey(
        for voice: VoiceDescriptor,
        languageCode: String?,
        preference: VoicePreference
    ) -> SortKey {
        let genderRank: Int
        switch voice.gender {
        case preference.gender: genderRank = 0
        case .unspecified: genderRank = 1
        default: genderRank = 2
        }

        let qualityRank = 2 - voice.quality.rawValue  // premium(2) → 0

        let isExactLocale =
            languageCode.map {
                voice.languageCode.caseInsensitiveCompare($0) == .orderedSame
            } ?? false
        let exactLocaleRank = isExactLocale ? 0 : 1

        return SortKey(
            gender: genderRank,
            quality: qualityRank,
            exactLocale: exactLocaleRank,
            identifier: voice.identifier
        )
    }

    /// Prefix-aware, case-insensitive language match. `nil` request matches
    /// everything. `"en"` matches `"en-US"`; `"en-US"` matches `"en-US"` but
    /// not `"en-GB"`; a bare `"en"` voice matches an `"en-US"` request (the
    /// language family is the same).
    private static func matchesLanguage(_ voiceLang: String, _ request: String?) -> Bool {
        guard let request, !request.isEmpty else { return true }
        let voiceFamily = languageFamily(voiceLang)
        let requestFamily = languageFamily(request)
        return voiceFamily.caseInsensitiveCompare(requestFamily) == .orderedSame
    }

    /// The primary language subtag — everything before the first `-`.
    /// `"en-US"` → `"en"`, `"en"` → `"en"`.
    private static func languageFamily(_ tag: String) -> String {
        if let dash = tag.firstIndex(of: "-") {
            return String(tag[..<dash])
        }
        return tag
    }

    private struct SortKey: Comparable {
        let gender: Int
        let quality: Int
        let exactLocale: Int
        let identifier: String

        static func < (lhs: SortKey, rhs: SortKey) -> Bool {
            if lhs.gender != rhs.gender { return lhs.gender < rhs.gender }
            if lhs.quality != rhs.quality { return lhs.quality < rhs.quality }
            if lhs.exactLocale != rhs.exactLocale { return lhs.exactLocale < rhs.exactLocale }
            return lhs.identifier < rhs.identifier
        }
    }
}

// MARK: - Preference persistence

/// Reads + writes the user's voice-gender preference to `UserDefaults`.
///
/// US-40 / AC-40.11 (T-720). The key is the canonical
/// `dod.voice.preferredGenderV1`; default is `.female` (AC-40.11). The
/// writer in v1 is the engine's own default-seeding path — the
/// **Settings → Voice** picker that lets the user flip the toggle is Phase b
/// (T-721, deferred behind the open Settings PRs). Exposed now so the engine
/// reads a real preference and the Phase-b UI has a store to bind to.
///
/// Not `Sendable` — it wraps a non-`Sendable` `UserDefaults`. In practice it
/// is constructed + read only on the `@MainActor` (via
/// ``SystemSpeechSynthesizer``); the value types it vends (``VoicePreference``)
/// are `Sendable` and cross actor boundaries freely.
public struct VoicePreferenceStore {

    /// Canonical UserDefaults key. `V1` suffix so a future schema change can
    /// migrate without colliding (mirrors `dod.cloudkit.syncOptInV1`).
    public static let genderKey = "dod.voice.preferredGenderV1"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The current preference, or the `.female` default when unset / unknown.
    public func preference() -> VoicePreference {
        guard let raw = defaults.string(forKey: Self.genderKey) else {
            return .default
        }
        switch raw {
        case "male": return VoicePreference(gender: .male)
        case "female": return VoicePreference(gender: .female)
        case "unspecified": return VoicePreference(gender: .unspecified)
        default: return .default
        }
    }

    /// Persist a gender preference. Phase b's Settings toggle calls this.
    public func setGender(_ gender: VoiceGender) {
        let raw: String
        switch gender {
        case .male: raw = "male"
        case .female: raw = "female"
        case .unspecified: raw = "unspecified"
        }
        defaults.set(raw, forKey: Self.genderKey)
    }
}
