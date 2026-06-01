#if canImport(UIKit)
import Foundation
import SwiftUI
import Testing
import UIKit

@testable import DODFeatureFeed

/// L1 coverage for ``AboutNedView`` — the About destination graduated
/// from T-550's "Coming soon — fetched from /about-me/" placeholder via
/// T-738 / CL-134 (DUT-14). Pins:
///   1. The verbatim DUT-14 copy. Any future paraphrase trips this test
///      so the change has to land via a deliberate spec amendment + CL
///      bump rather than silently shipping a drift to the user.
///   2. The bundled `AboutNed` image asset exists in `Bundle.main`.
///      Catches the regression where the asset is removed / renamed and
///      the view silently falls back to a transparent box at runtime.
///   3. The view instantiates without crashing — the cheapest insurance
///      against a mis-wired `Image(_:)` lookup or a SwiftUI body that
///      blows up under default trait collections.
///
/// Spec trace: US-32 AC-32.6 (the new AC graduated in T-738 / CL-134).
@MainActor
@Suite("AboutNedView (T-738 / DUT-14)") struct AboutNedViewTests {

    // MARK: - AC-32.6 — verbatim copy pin

    /// The exact paragraph from DUT-14. Stored as a separate constant
    /// inside the test so that a copy-paste edit on the production
    /// `AboutNedView.aboutNedCopy` constant won't accidentally pass this
    /// test (the test's copy is the source of truth for the assertion;
    /// any drift forces the spec author to update both places +
    /// graduate a CL).
    private static let expectedDUT14Copy: String =
        "Hi I'm Ned, the Dutch Oven Daddy! I'm a full-time computer nerd and part-time cook. My passion is cast iron cooking with tips, tricks, and delicious recipes. I love using my recipes to bring together family and friends. I believe everything is made better in cast iron!"

    @Test func aboutNedView_copy_matchesDUT14Verbatim() {
        #expect(AboutNedView.aboutNedCopy == Self.expectedDUT14Copy)
    }

    // MARK: - Asset bundle sanity

    @Test func aboutNedImageAsset_existsInBundle() {
        // `UIImage(named:in:with:)` returns non-nil iff the asset
        // catalog at the supplied bundle carries an imageset with the
        // requested name. The asset lives in `App/Assets.xcassets/
        // AboutNed.imageset/` which compiles into `Bundle.main` at app
        // build time. The DODFeatureFeed test bundle is hosted by the
        // app's test runner, so `Bundle.main` resolves to the app's
        // compiled bundle and the asset is reachable.
        let image = UIImage(named: "AboutNed", in: .main, with: nil)
        #expect(image != nil)
    }

    // MARK: - View construction sanity

    @Test func aboutNedView_rendersWithoutCrash() {
        // The cheapest "did SwiftUI's body close over a non-existent
        // symbol" guard. We don't assert anything about the rendered
        // pixels here (snapshot tests cover that); we just confirm the
        // view-struct construction + body evaluation doesn't throw or
        // crash under default trait collections.
        let view = AboutNedView()
        let host = UIHostingController(rootView: view)
        // Force the view to lay out so any lazy SwiftUI evaluation
        // happens inside this test scope rather than deferred to a
        // later snapshot.
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()
        #expect(host.view != nil)
    }
}
#endif
