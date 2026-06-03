#if canImport(UIKit)
import Foundation
import Testing
import UIKit

@testable import DODFeatureProfile

/// L1 coverage for the T-746 / CL-143 stale-photo-filename self-heal at
/// ``ProfileEditView`` mount. Tests the pure-async static helper
/// ``ProfileEditView/validatePhotoReferences(photoFilename:photoOriginalFilename:photoStore:)``
/// so the truth table is pinned without a view host (matches the
/// ``computeIsDirty(...)`` pattern in `ProfileEditViewDirtyStateTests`).
///
/// Truth table:
/// - Cropped filename + extant file → cropped stays populated.
/// - Cropped filename + missing file → cropped nils out.
/// - Original filename + extant file → original stays populated.
/// - Original filename + missing file → original nils out.
/// - Both filenames + only original missing → cropped stays, original nils.
/// - Both nil from start → both stay nil (no-op).
///
/// Spec trace: US-44 AC-44.8 amendment; CL-143.
@Suite("ProfileEditView photo validation (T-746)")
struct ProfileEditViewPhotoValidationTests {

    @Test func validatedFilenameStaysPopulatedWhenFileExists() async throws {
        let store = InMemoryProfilePhotoStore()
        let image = solidColorImage(side: 64, color: .red)
        let filename = try await store.save(image)

        let result = await ProfileEditView.validatePhotoReferences(
            photoFilename: filename,
            photoOriginalFilename: nil,
            photoStore: store
        )

        #expect(result.photoFilename == filename)
        #expect(result.photoOriginalFilename == nil)
    }

    @Test func staleFilenameNilsOutWhenFileMissing() async {
        // The dev-rebuild reproducer: Keychain row carries a filename,
        // but Documents was wiped on uninstall/install. The seed step
        // in `.onAppear` populates `inFlightPhotoFilename` from the
        // Keychain row — `.task` runs after and nils the stale ref.
        let store = InMemoryProfilePhotoStore()

        let result = await ProfileEditView.validatePhotoReferences(
            photoFilename: "profile-photo-stale-dev-rebuild.jpg",
            photoOriginalFilename: nil,
            photoStore: store
        )

        #expect(result.photoFilename == nil)
        #expect(result.photoOriginalFilename == nil)
    }

    @Test func validatedOriginalStaysPopulatedWhenFileExists() async throws {
        let store = InMemoryProfilePhotoStore()
        let image = solidColorImage(side: 128, color: .blue)
        let originalFilename = try await store.saveOriginal(image)

        let result = await ProfileEditView.validatePhotoReferences(
            photoFilename: nil,
            photoOriginalFilename: originalFilename,
            photoStore: store
        )

        #expect(result.photoFilename == nil)
        #expect(result.photoOriginalFilename == originalFilename)
    }

    @Test func staleOriginalNilsOutWhenFileMissing() async {
        let store = InMemoryProfilePhotoStore()

        let result = await ProfileEditView.validatePhotoReferences(
            photoFilename: nil,
            photoOriginalFilename: "profile-photo-original-stale.jpg",
            photoStore: store
        )

        #expect(result.photoFilename == nil)
        #expect(result.photoOriginalFilename == nil)
    }

    @Test func croppedStaysOriginalNilsWhenOnlyOriginalMissing() async throws {
        // Mixed state — the legacy-pre-T-745 user's cropped derivative
        // is intact but the (also-stored) original has been wiped (or
        // the user is pre-T-745 entirely + the seed populates only
        // the cropped). Edit Photo then falls back to re-cropping the
        // cropped per CL-142's legacy-fallback path, which is still
        // functional even after the original-side validation nils.
        let store = InMemoryProfilePhotoStore()
        let image = solidColorImage(side: 64, color: .green)
        let croppedFilename = try await store.save(image)

        let result = await ProfileEditView.validatePhotoReferences(
            photoFilename: croppedFilename,
            photoOriginalFilename: "profile-photo-original-missing.jpg",
            photoStore: store
        )

        #expect(result.photoFilename == croppedFilename)
        #expect(result.photoOriginalFilename == nil)
    }

    @Test func bothNilStaysBothNil() async {
        // No-op for a new-profile flow (user hasn't picked a photo
        // yet; the seed left both as nil; the validation is a cheap
        // no-op — no existence check fires).
        let store = InMemoryProfilePhotoStore()

        let result = await ProfileEditView.validatePhotoReferences(
            photoFilename: nil,
            photoOriginalFilename: nil,
            photoStore: store
        )

        #expect(result.photoFilename == nil)
        #expect(result.photoOriginalFilename == nil)
    }

    @Test func bothFilenamesValidStayPopulated() async throws {
        // Healthy state — both files present on disk (typical
        // post-T-745 returning user, no out-of-band wipe). Both
        // refs flow through unchanged.
        let store = InMemoryProfilePhotoStore()
        let croppedImage = solidColorImage(side: 64, color: .yellow)
        let originalImage = solidColorImage(side: 256, color: .yellow)
        let croppedFilename = try await store.save(croppedImage)
        let originalFilename = try await store.saveOriginal(originalImage)

        let result = await ProfileEditView.validatePhotoReferences(
            photoFilename: croppedFilename,
            photoOriginalFilename: originalFilename,
            photoStore: store
        )

        #expect(result.photoFilename == croppedFilename)
        #expect(result.photoOriginalFilename == originalFilename)
    }

    // MARK: - Helpers

    /// Renders a solid-color square `UIImage` so the test suite doesn't
    /// depend on a bundle resource fixture. Mirrors the helper in
    /// ``ProfilePhotoStoreTests``.
    private func solidColorImage(side: CGFloat, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        )
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: side, height: side)))
        }
    }
}
#endif
