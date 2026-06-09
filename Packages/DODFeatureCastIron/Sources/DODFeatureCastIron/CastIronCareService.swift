import Foundation

/// Orchestrates a cast-iron diagnosis: run the best available diagnoser and
/// fall back to curated care on unavailability, error, or a low-confidence
/// "not cast iron". The app talks only to this service; the tier ladder
/// (on-device vision -> Private Cloud Compute -> curated) is resolved by the
/// staged `CastIronDiagnoserResolver` and injected here as `diagnoser`.
public struct CastIronCareService: Sendable {
    private let diagnoser: CastIronDiagnoser?

    /// - Parameter diagnoser: the resolved best-available diagnoser, or `nil`
    ///   when none is available (offline + pre-iOS-27) -> curated fallback.
    public init(diagnoser: CastIronDiagnoser?) {
        self.diagnoser = diagnoser
    }

    /// Diagnose a photo. Never throws to the caller: any diagnoser failure
    /// degrades to curated general care so the user always gets actionable
    /// guidance rather than an error dead end.
    public func diagnose(_ image: CastIronImage) async -> CastIronDiagnosis {
        guard let diagnoser else { return CuratedCastIronCare.generalCare }
        do {
            let result = try await diagnoser.diagnose(image)
            // The model abstained / it isn't cast iron -> hand back curated
            // general care rather than a low-value "notCastIron" dead end.
            if result.condition == .notCastIron && result.confidence < 0.5 {
                return CuratedCastIronCare.generalCare
            }
            return result
        } catch {
            return CuratedCastIronCare.generalCare
        }
    }
}
