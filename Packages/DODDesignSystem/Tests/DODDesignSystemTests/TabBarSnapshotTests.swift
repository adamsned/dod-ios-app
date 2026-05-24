#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DODDesignSystem

/// L4 visual-regression baselines for the bottom tab bar (US-16).
///
/// The spec mandates baselines in light + dark, iPhone 13 + iPad 12.9",
/// with each tab selected (AC-16.5). Source of truth for the order and
/// icon mapping lives in App-target `AppTab.swift` and is pinned by
/// `DODAppUnitTests/AppTabTests`; these snapshots pin the *visual*
/// result so a font / chrome / icon-asset change surfaces as a pixel
/// diff in CI.
///
/// The renderer is a local fixture (`TabBarFixture`) that mirrors the
/// shipping `AppTab` order / labels / icons. The DesignSystem package
/// can't `@testable import DODApp`, so the four tabs are re-declared
/// here. Drift between the fixture and the real enum is guarded two
/// ways:
///   1. `DODAppUnitTests/AppTabTests` pins the App-side data.
///   2. `SmokeTests.test_tabBarOrderMatchesSpec` pins the App-side
///      rendered behavior.
/// If `App/AppTab.swift` and this fixture diverge, either (1) or (2)
/// fails loudly long before these snapshots silently misrepresent
/// reality.
///
/// Spec trace: constitution §6 L4, US-16 / AC-16.5.
final class TabBarSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        isRecording = false
    }

    // MARK: - iPhone 13

    func test_tabBar_feedSelected_light_iPhone13() {
        assertTabBarSnapshot(selected: .feed, dark: false, device: .iPhone13)
    }
    func test_tabBar_categoriesSelected_light_iPhone13() {
        assertTabBarSnapshot(selected: .categories, dark: false, device: .iPhone13)
    }
    func test_tabBar_savedSelected_light_iPhone13() {
        assertTabBarSnapshot(selected: .saved, dark: false, device: .iPhone13)
    }
    func test_tabBar_searchSelected_light_iPhone13() {
        assertTabBarSnapshot(selected: .search, dark: false, device: .iPhone13)
    }
    func test_tabBar_feedSelected_dark_iPhone13() {
        assertTabBarSnapshot(selected: .feed, dark: true, device: .iPhone13)
    }
    func test_tabBar_categoriesSelected_dark_iPhone13() {
        assertTabBarSnapshot(selected: .categories, dark: true, device: .iPhone13)
    }
    func test_tabBar_savedSelected_dark_iPhone13() {
        assertTabBarSnapshot(selected: .saved, dark: true, device: .iPhone13)
    }
    func test_tabBar_searchSelected_dark_iPhone13() {
        assertTabBarSnapshot(selected: .search, dark: true, device: .iPhone13)
    }

    // MARK: - iPad 12.9"

    func test_tabBar_feedSelected_light_iPad129() {
        assertTabBarSnapshot(selected: .feed, dark: false, device: .iPad129)
    }
    func test_tabBar_categoriesSelected_light_iPad129() {
        assertTabBarSnapshot(selected: .categories, dark: false, device: .iPad129)
    }
    func test_tabBar_savedSelected_light_iPad129() {
        assertTabBarSnapshot(selected: .saved, dark: false, device: .iPad129)
    }
    func test_tabBar_searchSelected_light_iPad129() {
        assertTabBarSnapshot(selected: .search, dark: false, device: .iPad129)
    }
    func test_tabBar_feedSelected_dark_iPad129() {
        assertTabBarSnapshot(selected: .feed, dark: true, device: .iPad129)
    }
    func test_tabBar_categoriesSelected_dark_iPad129() {
        assertTabBarSnapshot(selected: .categories, dark: true, device: .iPad129)
    }
    func test_tabBar_savedSelected_dark_iPad129() {
        assertTabBarSnapshot(selected: .saved, dark: true, device: .iPad129)
    }
    func test_tabBar_searchSelected_dark_iPad129() {
        assertTabBarSnapshot(selected: .search, dark: true, device: .iPad129)
    }

    /// Records on missing so the very first run lays down baselines
    /// rather than failing with "no snapshot found". Once committed,
    /// subsequent runs diff against the recorded PNG.
    private func assertTabBarSnapshot(
        selected: TabBarFixture.Tab,
        dark: Bool,
        device: TabBarFixture.Device,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let view =
            TabBarFixture(selected: selected)
            .frame(width: device.width, height: device.height)
            .preferredColorScheme(dark ? .dark : .light)
        assertSnapshot(
            of: view,
            as: .image(
                layout: .fixed(width: device.width, height: device.height),
                traits: UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
            ),
            record: .missing,
            file: file,
            testName: testName,
            line: line
        )
    }
}

/// Local mirror of `AppTab` for the DesignSystem snapshot tests. Lives
/// here because the App target isn't importable from this package.
/// Drift between this and the real `AppTab` is guarded by
/// `DODAppUnitTests/AppTabTests` (pins the App-side enum) and
/// `SmokeTests.test_tabBarOrderMatchesSpec` (pins the App-side render).
///
/// If you're editing this fixture, you almost certainly also need to
/// edit `App/AppTab.swift` to match — and vice versa.
private struct TabBarFixture: View {

    enum Tab: Hashable, CaseIterable {
        case feed, categories, saved, search

        var title: String {
            switch self {
            case .feed: "Recipes"
            case .categories: "Categories"
            case .saved: "Saved"
            case .search: "Search"
            }
        }

        var systemImage: String {
            switch self {
            case .feed: "house"
            case .categories: "square.grid.2x2"
            case .saved: "bookmark"
            case .search: "magnifyingglass"
            }
        }
    }

    enum Device {
        case iPhone13, iPad129

        /// Points, portrait. iPhone 13 is the constitutional perf-budget
        /// reference device (§8). iPad 12.9" is the largest iPad form
        /// factor we support.
        var width: CGFloat {
            switch self {
            case .iPhone13: 390
            case .iPad129: 1024
            }
        }
        var height: CGFloat {
            switch self {
            case .iPhone13: 844
            case .iPad129: 1366
            }
        }
    }

    let selected: Tab

    var body: some View {
        TabView(selection: .constant(selected)) {
            ForEach(Tab.allCases, id: \.self) { tab in
                // A plain colored panel is enough to anchor the tab bar
                // at the bottom of the screen — the snapshot's job is
                // to pin the tab bar's order + icons, not the per-tab
                // content.
                ZStack {
                    DODColor.surface.ignoresSafeArea()
                    Text(tab.title)
                        .font(.title)
                        .foregroundStyle(DODColor.labelSecondary)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .tint(DODColor.accent)
    }
}
#endif
