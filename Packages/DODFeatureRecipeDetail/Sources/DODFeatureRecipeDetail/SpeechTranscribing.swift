import Foundation

/// DUT-1029 — the narrow slice of on-device speech-to-text that Cook Mode's
/// hands-free questions drive. Lets the view model be tested with a mock
/// (no mic, no `SpeechAnalyzer`).
@MainActor
public protocol SpeechTranscribing: AnyObject {
    /// True only when on-device transcription is usable right now
    /// (iOS 26+, locale model installed, permission not denied).
    var isAvailable: Bool { get }

    /// Begin capturing mic audio. Returns a stream of transcript snapshots; each
    /// element is the full transcript so far (not a delta). The stream finishes
    /// after `stopListening()`.
    func startListening() -> AsyncStream<String>

    /// Stop capturing and finish the stream. Safe to call when not listening.
    func stopListening()
}

/// Default used when no real transcriber is injected (macOS test slice, older iOS).
@MainActor
public final class UnavailableSpeechTranscriber: SpeechTranscribing {
    public init() {}
    public var isAvailable: Bool { false }
    public func startListening() -> AsyncStream<String> {
        AsyncStream { $0.finish() }
    }
    public func stopListening() {}
}
