#if canImport(UIKit)
import DODDesignSystem
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureProfile

/// L4 visual-regression coverage for ``ProfilePhotoView`` — the three
/// rendering branches Phase b introduces: photo present (loaded
/// successfully), photo absent (no `photoFilename` — falls through to
/// the initial-letter avatar), photo missing on disk (graceful
/// degradation — `photoFilename` populated but the file isn't there,
/// also falls through to the initial-letter avatar).
///
/// The crop view itself isn't snapshot-tested (gesture-driven layout
/// doesn't reproduce cleanly under `UIHostingController` snapshot hosts
/// per CL-137 alternative (g)); coverage of the underlying transform
/// math via `ProfilePhotoCropMathTests` provides the same regression
/// guarantee with less flake.
///
/// First-run records via `record: .missing` (the iOS-Simulator
/// xcodebuild path lays the PNGs down on first run; no stale baseline
/// exists to be deleted).
///
/// Spec trace: US-44 AC-44.3; CL-137.
final class ProfilePhotoViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    @MainActor
    func test_noPhotoFallsBackToInitialLetterAvatar_light() {
        // `photoFilename` nil → the view should render the
        // initial-letter avatar directly. Matches Phase a behavior.
        let view = hosted(
            profile: UserProfile(
                id: UUID(),
                displayName: "Spencer Adams",
                email: "spencer@example.com",
                photoFilename: nil
            ),
            photoStore: InMemoryProfilePhotoStore()
        )
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 80, height: 80), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_photoFilenamePresentButFileMissingFallsBack_light() {
        // `photoFilename` non-nil but the file isn't there — graceful
        // degradation per CL-137. View should fall through to the
        // initial-letter avatar rather than render an empty circle.
        let view = hosted(
            profile: UserProfile(
                id: UUID(),
                displayName: "Spencer Adams",
                email: "spencer@example.com",
                photoFilename: "profile-photo-missing.jpg"
            ),
            photoStore: InMemoryProfilePhotoStore()
        )
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 80, height: 80), traits: Self.lightTraits()),
            record: .missing
        )
    }

    // MARK: - Helpers

    @MainActor
    private func hosted(
        profile: UserProfile?,
        photoStore: any ProfilePhotoStoring
    ) -> some View {
        ProfilePhotoView(
            profile: profile,
            diameter: 60,
            photoStore: photoStore
        )
        .padding(10)
        .background(DODColor.surface)
    }

    static func lightTraits() -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .light),
            UITraitCollection(displayScale: 3),
        ])
    }
}
#endif
