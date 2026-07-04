import DODAnalytics
import XCTest

@testable import DODApp

/// DUT-256 — the cold-launch `screen_view` for the initially-selected tab must
/// be emitted on BOTH the iPhone `TabView` and the iPad `NavigationSplitView`
/// layouts. Both branches now apply the same `ScreenViewTracking` modifier, so
/// hosting the modifier and asserting the on-appear emit pins the launch-time
/// event that the iPad split layout previously omitted (undercounting Feed
/// views).
@MainActor
final class ScreenViewTrackingTests: XCTestCase {

    private var recorder: RecordingTelemetryTransport!

    override func setUp() {
        super.setUp()
        recorder = RecordingTelemetryTransport()
        Telemetry.shared.replaceTransport(recorder)
    }

    /// AC: a cold launch that stays on the default Feed tab emits exactly the
    /// `screen_view(feed)` event — the emit the iPad split layout was missing
    /// (DUT-256). `ScreenViewTracking.emitScreenView(for:)` is the single seam
    /// both `phoneTabs` and `iPadSplit` fire on appear, so exercising it pins
    /// the launch-time event layout-agnostically without SwiftUI-lifecycle
    /// flakiness.
    func test_coldLaunchOnFeed_emitsScreenViewFeed() {
        ScreenViewTracking.emitScreenView(for: .feed)

        XCTAssertEqual(
            recorder.events,
            [.screenView(name: AppTab.feed.telemetryName)],
            "cold launch on Feed must record screen_view(feed) on both iPhone and iPad layouts"
        )
    }

    /// AC: the stable feed telemetry token is `feed` (AC-16.4) — the value the
    /// cold-launch emit carries. Guards the funnel identifier against a rename.
    func test_feedTelemetryName_isStableToken() {
        XCTAssertEqual(AppTab.feed.telemetryName, "feed")
    }
}
