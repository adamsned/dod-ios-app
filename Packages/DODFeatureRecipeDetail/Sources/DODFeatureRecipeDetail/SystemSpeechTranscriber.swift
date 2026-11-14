import Foundation

#if os(iOS) && canImport(Speech) && canImport(AVFoundation) && compiler(>=6.4)
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

    /// Configure the shared audio session for mic capture, ducking other audio.
    fileprivate func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers])
        try session.setActive(true)
    }

    /// Build the on-device transcriber with volatile (partial) results.
    fileprivate func makeTranscriber() -> SpeechTranscriber {
        SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
    }
}

// MARK: - Helper Functions

@available(iOS 26.0, *)
extension SystemSpeechTranscriber {
    /// Fold one recognizer result into the running full-transcript snapshot.
    nonisolated static func snapshot(finalized: inout String, text: String, isFinal: Bool) -> String {
        if isFinal {
            finalized += text
            return finalized
        }
        return finalized + text
    }

    /// Convert audio buffer using AVAudioConverter with proper sample rate handling.
    nonisolated static func convert(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter,
        to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return buffer
        }
        return status == .error ? nil : out
    }

    /// Create a tap block for AVAudioNode that yields analyzer input.
    nonisolated static func makeTapBlock(
        builder: AsyncStream<AnalyzerInput>.Continuation,
        converter: AVAudioConverter?,
        format: AVAudioFormat
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard let converter else {
                builder.yield(AnalyzerInput(buffer: buffer))
                return
            }
            if let out = convert(buffer, with: converter, to: format) {
                builder.yield(AnalyzerInput(buffer: out))
            }
        }
    }

    /// Install the mic tap (converting to the analyzer's format if needed) and start the engine.
    fileprivate func startEngine(
        format: AVAudioFormat,
        builder: AsyncStream<AnalyzerInput>.Continuation
    ) throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        let converter = inputFormat == format ? nil : AVAudioConverter(from: inputFormat, to: format)
        let block = Self.makeTapBlock(builder: builder, converter: converter, format: format)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat, block: block)
        engine.prepare()
        try engine.start()
    }
}
#endif
