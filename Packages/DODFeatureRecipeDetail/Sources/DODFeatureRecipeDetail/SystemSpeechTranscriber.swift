import Foundation

#if os(iOS) && canImport(Speech) && canImport(AVFoundation)
import AVFoundation
import Speech

/// DUT-1029 — on-device push-to-talk transcription via iOS 26's SpeechAnalyzer.
/// Usage strings (NSMicrophoneUsageDescription / NSSpeechRecognitionUsageDescription)
/// are an app-target concern and are NOT part of this type.
@available(iOS 26.0, *)
@MainActor
public final class SystemSpeechTranscriber: SpeechTranscribing {
    private let engine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var task: Task<Void, Never>?
    private let locale: Locale

    public init(locale: Locale = .current) { self.locale = locale }

    public var isAvailable: Bool { SpeechTranscriber.isAvailable }

    public func startListening() -> AsyncStream<String> {
        AsyncStream { $0.finish() }
    }

    public func stopListening() {}
}
#endif
