import DODDomain
import Foundation
import ImageIO
import Vision

// DUT-1004: on-device recipe-card OCR. Vision is available on iOS 17+ and
// macOS 14+, so this needs no FoundationModels availability gate.
extension LiveDODIntelligenceService {

    public func scanRecipeCard(imageData: Data) async -> FamilyRecipe? {
        guard !imageData.isEmpty else { return nil }
        guard let text = Self.recognizeText(in: imageData) else { return nil }
        return RecipeCardTextParser.parse(text)
    }

    /// Runs Vision's accurate text recognizer over the image bytes. Returns the
    /// recognised lines joined by newlines, or `nil` on undecodable bytes,
    /// a Vision error, or no recognised text.
    static func recognizeText(in imageData: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        let lines = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}
