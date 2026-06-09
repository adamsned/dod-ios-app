#if CASTIRON_IOS27
import Foundation
import FoundationModels
#if canImport(UIKit)
import UIKit
#endif

/// Private Cloud Compute cast-iron diagnoser - the fallback for devices
/// without the on-device advanced (vision) model. Apple-operated Private
/// Cloud Compute is free for developers under 2M first-time downloads (DOD
/// qualifies) and is NOT a third party, so it avoids the constitution
/// section 9 conflict the original cloud-LLM option (Claude / GPT-4V) would
/// trip - no new third-party data-sharing surface.
///
/// STAGED - NOT COMPILED BY DEFAULT (see `FoundationModelsCastIronDiagnoser`).
/// The PCC model API is written against Apple's documented surface and pending
/// a real-SDK compile.
@available(iOS 27.0, *)
public struct PrivateCloudComputeCastIronDiagnoser: CastIronDiagnoser {
    public init() {}

    public func diagnose(_ image: CastIronImage) async throws -> CastIronDiagnosis {
        guard let uiImage = UIImage(data: image.data) else {
            throw CastIronDiagnoserError.invalidImage
        }
        let session = LanguageModelSession(
            model: PrivateCloudComputeLanguageModel(),
            instructions: castIronInstructions
        )
        let response = try await session.respond(generating: GeneratedDiagnosis.self) {
            castIronPrompt
            Attachment(uiImage)
        }
        return response.content.asDiagnosis(source: .privateCloudCompute)
    }
}
#endif
