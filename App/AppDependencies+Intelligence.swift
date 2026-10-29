import DODIntelligence
import Foundation

// v2 on-device AI (1/n) — the shared intelligence-service factory, split out of
// `AppDependencies.swift` (file_length cap) and mirroring the
// `shoppingListAppender()` composition seam.
extension AppDependencies {

    /// The app's on-device intelligence service (v2). Production returns the
    /// FoundationModels-backed ``LiveDODIntelligenceService``, which degrades to
    /// "unavailable" on iOS 17-25, incapable hardware, the simulator, and when
    /// Apple Intelligence is off — so every consumer's affordance hides itself
    /// via ``DODIntelligenceService/isAvailable``.
    ///
    /// A UI-test launch arg (`-DODFakeIntelligence`) swaps in a deterministic
    /// ``FakeIntelligenceService`` so a future XCUITest can exercise the
    /// substitution surface without the (sim-unavailable, non-deterministic)
    /// real model. The live model itself is NOT exercised in any automated gate.
    func intelligenceService() -> any DODIntelligenceService {
        if ProcessInfo.processInfo.arguments.contains("-DODFakeIntelligence") {
            return FakeIntelligenceService()
        }
        return LiveDODIntelligenceService()
    }
}
