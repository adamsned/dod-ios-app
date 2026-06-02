#if canImport(UIKit)
import DODDesignSystem
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureProfile

/// L4 visual-regression coverage for ``InitialLetterAvatarView`` — the
/// default avatar that fronts the Profile section when the user has not
/// uploaded a photo yet (Phase b's job). Four baselines lock the
/// letter-extraction + accent-fill + sizing register against silent
/// drift on the brand palette (US-43 / CL-128 last touched
/// `DODColor.accent` indirectly via the family revert; future palette
/// shuffles need a visible diff here so the Profile section's identity
/// cue stays the same shade users learned in Phase a).
///
/// First-run records via `record: .missing` (the iOS-Simulator xcodebuild
/// path lays the PNGs down on first run; the same `.gitkeep` placeholder
/// pattern as `DODFeatureFeed`'s baselines, so no stale baseline exists
/// to be deleted).
///
/// Spec trace: US-44 AC-44.5; CL-136.
final class InitialLetterAvatarViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    @MainActor
    func test_avatar_singleLetter_light() {
        let view = hosted(displayName: "Alice")
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 80, height: 80), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_avatar_twoWordName_light() {
        // "Spencer Adams" → "S" — the first-letter-of-first-word rule.
        let view = hosted(displayName: "Spencer Adams")
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 80, height: 80), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_avatar_emojiPrefix_light() {
        // "🌟 Spencer" → "S" — skip the emoji, pick the first letter.
        let view = hosted(displayName: "🌟 Spencer")
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 80, height: 80), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_avatar_fallback_questionMark_light() {
        // Empty input → "?" fallback. Locks the documented degradation
        // (the view never crashes; it falls back to a glyph).
        let view = hosted(displayName: "")
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 80, height: 80), traits: Self.lightTraits()),
            record: .missing
        )
    }

    @MainActor
    func test_avatar_singleLetter_dark() {
        let view = hosted(displayName: "Alice")
        assertSnapshot(
            of: view,
            as: .image(layout: .fixed(width: 80, height: 80), traits: Self.darkTraits()),
            record: .missing
        )
    }

    // MARK: - Helpers

    @MainActor
    private func hosted(displayName: String) -> some View {
        InitialLetterAvatarView(displayName: displayName, diameter: 60)
            .padding(10)
            .background(DODColor.surface)
    }

    static func lightTraits() -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .light),
            UITraitCollection(displayScale: 3),
        ])
    }

    static func darkTraits() -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(displayScale: 3),
        ])
    }
}
#endif
