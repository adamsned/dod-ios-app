#if canImport(UIKit)
import DODDomain
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureRecipeDetail

/// DUT-956 — owner-agnostic PNG render of ``CommenterProfileSheet`` for visual
/// preview. NOT a tracked snapshot baseline (no `__Snapshots__` entry, nothing
/// CI-gated) — it renders a sample commenter to a file under the scratchpad out
/// dir so the sheet can be eyeballed without booting the whole app. Skips
/// silently when the out dir isn't present (i.e. anywhere but this workspace).
final class CommenterProfileSheetRenderTests: XCTestCase {

    private static let outDir =
        "/private/tmp/claude-501/-Users-spenceradams-Work/"
        + "81ede92f-652e-4a0a-8ec1-278453a34918/scratchpad/commenter-sheet-out"

    @MainActor
    func test_render_commenterProfileSheet_png() throws {
        let outURL = URL(fileURLWithPath: Self.outDir, isDirectory: true)
        try FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)

        let comment = RecipeComment(
            id: 4242,
            postID: 902,
            authorName: "Jamie L.",
            avatarURL: nil,  // exercises the SF-symbol placeholder fallback
            dateGMT: Date(timeIntervalSince1970: 1_700_000_000),
            body: "Made this last night and it was incredible.",
            ratingValue: 5,
            status: .approved
        )
        let sheet = CommenterProfileSheet(
            comment: comment,
            displayName: "Jamie L.",
            onReport: {},
            onBlock: {}
        )

        let image = Self.render(sheet, size: CGSize(width: 393, height: 720))
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: outURL.appendingPathComponent("commenter-profile-sheet.png"))
    }

    @MainActor
    private static func render(_ view: some View, size: CGSize) -> UIImage {
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.backgroundColor = UIColor.systemBackground

        let window = UIWindow(frame: host.view.frame)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(bounds: host.view.bounds)
        return renderer.image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
    }
}
#endif
