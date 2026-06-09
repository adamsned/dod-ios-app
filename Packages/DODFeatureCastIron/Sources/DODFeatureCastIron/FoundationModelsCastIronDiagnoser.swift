#if CASTIRON_IOS27
import Foundation
import FoundationModels
#if canImport(UIKit)
import UIKit
#endif

/// On-device cast-iron diagnoser backed by the iOS 27 Foundation Models
/// vision model (WWDC 2026).
///
/// STAGED - NOT COMPILED BY DEFAULT. The `Attachment` image API ships only in
/// the iOS 27 SDK, so this file is gated behind `CASTIRON_IOS27` and excluded
/// from the Xcode 26 build. Enable with `-Xswiftc -DCASTIRON_IOS27` once the
/// Xcode 27 beta toolchain is installed, then verify the exact signatures
/// against the real SDK: it is written against Apple's documented API
/// (developer.apple.com/videos/play/wwdc2026/241) and not yet compile-checked.
///
/// Needs the on-device advanced (vision-capable) model - iPhone 15 Pro and
/// later. Older devices route to `PrivateCloudComputeCastIronDiagnoser`.
@available(iOS 27.0, *)
public struct FoundationModelsCastIronDiagnoser: CastIronDiagnoser {
    public init() {}

    public func diagnose(_ image: CastIronImage) async throws -> CastIronDiagnosis {
        guard let uiImage = UIImage(data: image.data) else {
            throw CastIronDiagnoserError.invalidImage
        }
        let session = LanguageModelSession(instructions: castIronInstructions)
        let response = try await session.respond(generating: GeneratedDiagnosis.self) {
            castIronPrompt
            Attachment(uiImage)
        }
        return response.content.asDiagnosis(source: .onDeviceVision)
    }
}

/// Shared system instructions for the cast-iron diagnosers. Anchored on the
/// curated knowledge base so model answers read consistently with the offline
/// fallback content.
@available(iOS 27.0, *)
let castIronInstructions = """
    You are Dutch Oven Daddy's cast iron care expert. Look at the photo and \
    classify the cookware's condition as exactly one of: wellSeasoned, \
    sticky, lightRust, heavyRust, cracked, neverSeasoned, or notCastIron. \
    Then give clear, beginner-friendly restore or care steps, most important \
    first. Always warn the user to retire a cracked pan from cooking. If the \
    photo is not cast iron, set condition to notCastIron with low confidence.
    """

@available(iOS 27.0, *)
let castIronPrompt = "Diagnose this cast iron's condition and give care steps."

/// The `@Generable` shape the on-device model fills in, mapped into the core
/// `CastIronDiagnosis` value type so the rest of the app never depends on
/// Foundation Models.
@available(iOS 27.0, *)
@Generable
struct GeneratedDiagnosis {
    @Guide(description: "One of: wellSeasoned, sticky, lightRust, heavyRust, cracked, neverSeasoned, notCastIron")
    var condition: String
    @Guide(description: "0 to 1 confidence this is cast iron and the condition is correct")
    var confidence: Double
    @Guide(description: "One or two beginner-friendly sentences about what you see")
    var summary: String
    @Guide(description: "Ordered care steps, most important first")
    var steps: [GeneratedStep]
    @Guide(description: "A safety caveat if relevant, otherwise an empty string")
    var safetyNote: String

    @Generable
    struct GeneratedStep {
        @Guide(description: "Short imperative title, e.g. Scrub with coarse salt")
        var title: String
        @Guide(description: "One sentence of detail")
        var detail: String
    }

    func asDiagnosis(source: CastIronDiagnosis.Source) -> CastIronDiagnosis {
        CastIronDiagnosis(
            condition: CastIronCondition(rawValue: condition) ?? .notCastIron,
            confidence: confidence,
            summary: summary,
            steps: steps.enumerated().map { index, step in
                CareStep(id: index + 1, title: step.title, detail: step.detail)
            },
            safetyNote: safetyNote.isEmpty ? nil : safetyNote,
            source: source
        )
    }
}
#endif
