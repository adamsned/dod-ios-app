import Foundation

extension CastIronCareService {
    /// The composition entry point the app uses: the best diagnoser the
    /// current build + device can offer.
    ///
    /// - Built with `-D CASTIRON_IOS27` (Xcode 27 beta+) on an iOS 27 device:
    ///   the `CastIronDiagnoserResolver` tier ladder (on-device vision ->
    ///   Private Cloud Compute).
    /// - Default build (Xcode 26, the current toolchain): no diagnoser - the
    ///   service serves curated care and the screen leans on the manual
    ///   condition picker.
    public static func bestAvailable() -> CastIronCareService {
        #if CASTIRON_IOS27
            if #available(iOS 27.0, *) {
                return CastIronCareService(diagnoser: CastIronDiagnoserResolver.resolve())
            }
            return CastIronCareService(diagnoser: nil)
        #else
            return CastIronCareService(diagnoser: nil)
        #endif
    }
}
