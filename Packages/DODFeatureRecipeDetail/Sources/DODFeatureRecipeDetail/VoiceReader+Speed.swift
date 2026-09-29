import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

/// Voice pacing for ``VoiceReader`` (DUT-325 / DUT-583) — the clamped rate
/// bounds, the discrete Cook Mode speed list, and the step nudgers. Split out of
/// `VoiceReader.swift` so that file stays under the SwiftLint `file_length` cap.
extension VoiceReader {

    /// A calming factor on the natural (1×) narration pace. AVSpeechUtterance's
    /// default rate reads a touch fast for hands-free, step-by-step cooking, so
    /// `1×` anchors slightly BELOW the platform default for an audiobook/podcast
    /// feel (and every multiplier scales from there, so the whole range is
    /// gentler than the raw engine rates).
    ///
    /// TUNABLE — the true pace can only be judged on a REAL DEVICE: the
    /// Simulator ships only robotic/compact voices that race and garble far
    /// worse than a natural device voice (see the voice-catalog note). Nudge
    /// this one constant after testing on hardware if `1×`/`1.25×` still feel
    /// fast.
    static var naturalPaceScale: Float { 0.9 }

    /// The app's natural (1×) narration rate — the platform default, calmed for
    /// cooking by ``naturalPaceScale``. Every discrete speed is a multiple of
    /// this, so `1×` is the app's comfortable pace rather than the raw engine
    /// default.
    static var naturalRate: Float { Self.defaultRate * Self.naturalPaceScale }

    /// The lowest rate the speed control allows — `0.75×` the natural pace. Slow
    /// enough to follow a tricky step, never so slow it drags.
    static var minimumRate: Float { Self.naturalRate * 0.75 }
    /// The highest rate the speed control allows — `1.5×` the natural pace. A
    /// comfortable audiobook top end; the old `1.75×`/`2×` garbled the voice, so
    /// they were dropped (podcast/audiobook feel, per feedback).
    static var maximumRate: Float { Self.naturalRate * 1.5 }
    /// Per-tap increment for the legacy nudgers (a fraction of the natural pace)
    /// so a couple of taps spans the comfortable range.
    static var rateStep: Float { Self.naturalRate * 0.15 }

    /// The platform default speech rate. `AVSpeechUtteranceDefaultSpeechRate`
    /// where AVFoundation exists; a matching constant on the fallback slice.
    static var defaultRate: Float {
        #if canImport(AVFoundation)
        AVSpeechUtteranceDefaultSpeechRate
        #else
        0.5
        #endif
    }

    /// The discrete playback speeds the Cook Mode speed button cycles through, as
    /// multipliers of the natural (1×) rate. `1.0` is the default. Reworked to a
    /// gentle podcast/audiobook range (feedback): the jarring `1.75×`/`2×` top
    /// end and the draggy `0.5×` bottom are gone, and a soft `1.1×` sits between
    /// `1×` and `1.25×`. The extremes line up exactly with ``minimumRate``
    /// (`0.75×`) and ``maximumRate`` (`1.5×`) so ``rate(for:)`` never clamps them.
    public static let speedMultipliers: [Double] = [0.75, 1.0, 1.1, 1.25, 1.5]

    /// Map a speed multiplier (`1.0` = the app's natural pace) to the clamped
    /// engine rate. Cook Mode owns the discrete list; this turns a chosen
    /// multiplier into the `AVSpeechUtterance.rate` the engine understands.
    public static func rate(for multiplier: Double) -> Float {
        min(Self.maximumRate, max(Self.minimumRate, Self.naturalRate * Float(multiplier)))
    }

    /// DUT-325 — nudge the session speech rate up one step (clamped). Returns
    /// the new rate so the caller can decide whether to re-speak.
    @discardableResult
    public func speedUp() -> Float {
        speechRate = min(Self.maximumRate, speechRate + Self.rateStep)
        return speechRate
    }

    /// DUT-325 — nudge the session speech rate down one step (clamped).
    @discardableResult
    public func slowDown() -> Float {
        speechRate = max(Self.minimumRate, speechRate - Self.rateStep)
        return speechRate
    }
}
