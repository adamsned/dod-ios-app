import Foundation

/// Opaque image payload for a diagnoser. `Data` (JPEG/PNG bytes) keeps the
/// protocol portable - no UIKit - so the package builds + tests on any host;
/// the iOS 27 diagnosers convert it to a `UIImage` for an `Attachment`.
public struct CastIronImage: Sendable, Equatable {
    public var data: Data
    public init(data: Data) { self.data = data }
}

/// Produces a `CastIronDiagnosis` from a photo. Implementations: the iOS 27
/// on-device vision model and the iOS 27 Private Cloud Compute model (both
/// staged behind `CASTIRON_IOS27`), plus test mocks. Selection lives in the
/// staged `CastIronDiagnoserResolver`; the result is injected into
/// `CastIronCareService`.
public protocol CastIronDiagnoser: Sendable {
    func diagnose(_ image: CastIronImage) async throws -> CastIronDiagnosis
}

/// Errors a diagnoser can surface. Kept in the core (un-gated) so the staged
/// iOS 27 diagnosers and any fallback path share one error type.
public enum CastIronDiagnoserError: Error, Equatable, Sendable {
    case invalidImage
    case modelUnavailable
}
