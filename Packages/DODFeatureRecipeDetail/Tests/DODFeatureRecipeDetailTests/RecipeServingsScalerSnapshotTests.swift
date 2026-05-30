#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureRecipeDetail

/// L4 visual-regression coverage for ``RecipeServingsScaler``.
///
/// Pins the stepper layout at three representative scale points:
/// default (= recipe yield), 8 servings (scaled up, no warning), 16
/// servings (scaled past the dutch-oven capacity threshold — warning
/// caption visible). Light + dark for each so the appearance audit
/// captures both modes.
///
/// First run with `isRecording = false` to create baselines, then revert
/// and commit. Subsequent runs diff against the baselines.
///
/// Spec trace: constitution §6 L4, US-31 / AC-31.1 + AC-31.6.
final class RecipeServingsScalerSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Flip to true locally to refresh baselines after an intentional
        // visual change, then revert before commit.
        isRecording = false
    }

    @MainActor
    func test_servingsScaler_default() {
        assertScaler(value: 4, source: 4, showsWarning: false, dark: false)
    }

    @MainActor
    func test_servingsScaler_default_dark() {
        assertScaler(value: 4, source: 4, showsWarning: false, dark: true)
    }

    @MainActor
    func test_servingsScaler_scaledUp() {
        assertScaler(value: 8, source: 4, showsWarning: false, dark: false)
    }

    @MainActor
    func test_servingsScaler_scaledUp_dark() {
        assertScaler(value: 8, source: 4, showsWarning: false, dark: true)
    }

    @MainActor
    func test_servingsScaler_warningThreshold() {
        // 16 > 12 → warning caption renders. AC-31.6.
        assertScaler(value: 16, source: 4, showsWarning: true, dark: false)
    }

    @MainActor
    func test_servingsScaler_warningThreshold_dark() {
        assertScaler(value: 16, source: 4, showsWarning: true, dark: true)
    }

    @MainActor
    private func assertScaler(
        value: Int,
        source: Int,
        showsWarning: Bool,
        dark: Bool,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let view = harness(value: value, source: source, showsWarning: showsWarning)
            .frame(width: 390)
            .preferredColorScheme(dark ? .dark : .light)
        assertSnapshot(
            of: view,
            as: .image(
                layout: .sizeThatFits,
                traits: UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
            ),
            file: file,
            testName: testName,
            line: line
        )
    }

    // MARK: - Helpers

    /// Wraps the scaler in a `StepperHost` so the `@Binding` resolves
    /// against a stable initial value. The harness disables the actual
    /// binding so snapshots are deterministic.
    @MainActor
    private func harness(value: Int, source: Int, showsWarning: Bool) -> some View {
        StepperHost(
            initialValue: value,
            range: 1...24,
            sourceServings: source,
            showsWarning: showsWarning
        )
    }
}

private struct StepperHost: View {
    @State var initialValue: Int
    let range: ClosedRange<Int>
    let sourceServings: Int
    let showsWarning: Bool

    var body: some View {
        RecipeServingsScaler(
            value: $initialValue,
            range: range,
            sourceServings: sourceServings,
            showsWarning: showsWarning
        )
    }
}
#endif
