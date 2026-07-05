import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

/// Voice pacing for ``VoiceReader`` (DUT-325 / DUT-583) — the clamped rate
/// bounds, the discrete Cook Mode speed list, and the step nudgers. Split out of
/// `VoiceReader.swift` so that file stays under the SwiftLint `file_length` cap.
extension VoiceReader {

    /// The lowest rate the session menu allows — half the platform default
    /// (≈0.5×). Slow enough to follow a tricky step, never so slow it drags.
    static var minimumRate: Float { Self.defaultRate * 0.5 }
    /// The highest rate the session menu allows — double the platform default
    /// (≈2×). Fast enough to skim, never so fast it garbles.
    static var maximumRate: Float { Self.defaultRate * 2 }
    /// Per-tap increment (a fifth of the default span) so a couple of taps
    /// spans the comfortable range.
    static var rateStep: Float { Self.defaultRate * 0.15 }

    /// The platform default speech rate. `AVSpeechUtteranceDefaultSpeechRate`
    /// where AVFoundation exists; a matching constant on the fallback slice.
    static var defaultRate: Float {
        #if canImport(AVFoundation)
        AVSpeechUtteranceDefaultSpeechRate
        #else
        0.5
        #endif
    }

    /// DUT-583 — the discrete playback speeds the Cook Mode speed button cycles
    /// through, as multipliers of the natural (1×) rate. `1.0` is the default;
    /// the extremes line up exactly with ``minimumRate`` (0.5×) and
    /// ``maximumRate`` (2×) so ``rate(for:)`` never has to clamp them.
    public static let speedMultipliers: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    /// DUT-583 — map a speed multiplier (`1.0` = natural pace) to the clamped
    /// engine rate. Cook Mode owns the discrete list; this turns a chosen
    /// multiplier into the `AVSpeechUtterance.rate` the engine understands.
    public static func rate(for multiplier: Double) -> Float {
        min(Self.maximumRate, max(Self.minimumRate, Self.defaultRate * Float(multiplier)))
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
