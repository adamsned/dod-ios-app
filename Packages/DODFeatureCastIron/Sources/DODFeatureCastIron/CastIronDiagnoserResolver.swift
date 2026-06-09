#if CASTIRON_IOS27
import Foundation
import FoundationModels

/// Resolves the best available cast-iron diagnoser for the current device and
/// OS; the app hands the result to `CastIronCareService`:
///
/// 1. On-device vision (`FoundationModelsCastIronDiagnoser`) when the advanced
///    model is available (iPhone 15 Pro+) - free, private, works offline.
/// 2. Private Cloud Compute (`PrivateCloudComputeCastIronDiagnoser`) otherwise
///    - free, private, Apple-operated, needs a network connection.
/// 3. `nil` -> `CastIronCareService` falls back to curated offline content.
///
/// STAGED - NOT COMPILED BY DEFAULT. The capability probe is written against
/// Apple's documented `SystemLanguageModel` availability surface and pending a
/// real-SDK compile to confirm how the *vision* capability is distinguished
/// from the text-only on-device model (older hardware).
@available(iOS 27.0, *)
public enum CastIronDiagnoserResolver {
    public static func resolve() -> CastIronDiagnoser? {
        switch SystemLanguageModel.default.availability {
        case .available:
            // Advanced on-device model present (vision-capable hardware).
            return FoundationModelsCastIronDiagnoser()
        default:
            // No usable on-device model -> Apple PCC keeps it free + private.
            return PrivateCloudComputeCastIronDiagnoser()
        }
    }
}
#endif
