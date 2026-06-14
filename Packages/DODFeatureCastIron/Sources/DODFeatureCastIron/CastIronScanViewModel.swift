import Foundation
import Observation

/// Drives the Cast Iron Scanner screen (DUT-13): intro -> diagnosing ->
/// result. Two ways into a result:
///
/// - **Photo** (`diagnose(imageData:)`): routes through
///   ``CastIronCareService`` - the on-device / PCC model on iOS 27, curated
///   general care everywhere else. Never fails; the service degrades
///   internally.
/// - **Manual** (`choose(condition:)`): the user picks what their pan looks
///   like and gets the curated guide directly. This keeps the walkthrough
///   fully useful on iOS 26 today and doubles as the "model abstained" path.
@MainActor
@Observable
public final class CastIronScanViewModel {

    public enum Phase: Equatable {
        case intro
        case diagnosing
        case result(CastIronDiagnosis)
    }

    public private(set) var phase: Phase = .intro

    private let service: CastIronCareService

    public init(service: CastIronCareService) {
        self.service = service
    }

    /// Diagnose a captured/picked photo. The service never throws - any
    /// model failure lands on curated general care, so this always reaches
    /// `.result`.
    public func diagnose(imageData: Data) async {
        phase = .diagnosing
        let diagnosis = await service.diagnose(CastIronImage(data: imageData))
        phase = .result(diagnosis)
    }

    /// Manual fallback: the user tells us what the pan looks like.
    public func choose(condition: CastIronCondition) {
        phase = .result(CuratedCastIronCare.guide(for: condition))
    }

    /// Back to the intro for another scan.
    public func reset() {
        phase = .intro
    }
}
