import XCTest

@testable import DODDesignSystem

/// L1 unit coverage for ``StepProgress`` — the pure, SwiftUI-free progress model
/// behind First Cookout's paged-flow footer. Covers first/last/empty/out-of-range so the
/// fraction, caption, and accessibility copy stay correct without booting a view.
final class StepProgressTests: XCTestCase {

    // MARK: - First step

    func test_firstStep_fractionCaptionAndFlags() {
        let progress = StepProgress(currentIndex: 0, count: 5)
        XCTAssertEqual(progress.activeIndex, 0)
        XCTAssertEqual(progress.fraction, 1.0 / 5.0, accuracy: 0.0001)
        XCTAssertEqual(progress.caption, "Step 1 of 5")
        XCTAssertEqual(progress.accessibilityLabel, "Step 1 of 5")
        XCTAssertTrue(progress.isFirst)
        XCTAssertFalse(progress.isLast)
    }

    // MARK: - Middle step

    func test_middleStep_fractionAndCaption() {
        let progress = StepProgress(currentIndex: 2, count: 5)
        XCTAssertEqual(progress.fraction, 3.0 / 5.0, accuracy: 0.0001)
        XCTAssertEqual(progress.caption, "Step 3 of 5")
        XCTAssertFalse(progress.isFirst)
        XCTAssertFalse(progress.isLast)
    }

    // MARK: - Last step

    func test_lastStep_isFullyComplete() {
        let progress = StepProgress(currentIndex: 4, count: 5)
        XCTAssertEqual(progress.fraction, 1.0, accuracy: 0.0001)
        XCTAssertEqual(progress.caption, "Step 5 of 5")
        XCTAssertFalse(progress.isFirst)
        XCTAssertTrue(progress.isLast)
    }

    // MARK: - Empty walkthrough (count == 0)

    func test_emptyCount_clampsToSingleStepWithoutDivideByZero() {
        let progress = StepProgress(currentIndex: 0, count: 0)
        XCTAssertEqual(progress.count, 1)
        XCTAssertEqual(progress.activeIndex, 0)
        XCTAssertEqual(progress.fraction, 1.0, accuracy: 0.0001)
        XCTAssertEqual(progress.caption, "Step 1 of 1")
        XCTAssertTrue(progress.isFirst)
        XCTAssertTrue(progress.isLast)
    }

    // MARK: - Out-of-range indices clamp into 0..<count

    func test_negativeIndex_clampsToFirst() {
        let progress = StepProgress(currentIndex: -3, count: 4)
        XCTAssertEqual(progress.activeIndex, 0)
        XCTAssertEqual(progress.caption, "Step 1 of 4")
        XCTAssertTrue(progress.isFirst)
    }

    func test_indexBeyondCount_clampsToLast() {
        let progress = StepProgress(currentIndex: 99, count: 4)
        XCTAssertEqual(progress.activeIndex, 3)
        XCTAssertEqual(progress.fraction, 1.0, accuracy: 0.0001)
        XCTAssertEqual(progress.caption, "Step 4 of 4")
        XCTAssertTrue(progress.isLast)
    }

    // MARK: - Single-step walkthrough is both first and last

    func test_singleStep_isFirstAndLast() {
        let progress = StepProgress(currentIndex: 0, count: 1)
        XCTAssertTrue(progress.isFirst)
        XCTAssertTrue(progress.isLast)
        XCTAssertEqual(progress.fraction, 1.0, accuracy: 0.0001)
        XCTAssertEqual(progress.caption, "Step 1 of 1")
    }
}
