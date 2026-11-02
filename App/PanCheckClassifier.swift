import DODSupport
import Foundation
import Vision

/// DUT-992 — on-device pan classification. Image in, `PanCheck.Verdict` out.
protocol PanCheckClassifying: Sendable {
    func verdict(for cgImage: CGImage) async -> PanCheck.Verdict
}

struct VisionPanCheckClassifier: PanCheckClassifying {
    func verdict(for cgImage: CGImage) async -> PanCheck.Verdict {
        await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            guard (try? handler.perform([request])) != nil else { return PanCheck.Verdict.unclear }
            let labels = (request.results ?? []).map { (identifier: $0.identifier, confidence: $0.confidence) }
            return PanCheck.verdict(fromLabels: labels)
        }.value
    }
}
