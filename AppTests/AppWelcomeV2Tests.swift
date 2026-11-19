import DODDesignSystem
import XCTest

@testable import DODApp

/// DUT-2896 — the v2 App Welcome copy: a summary intro, a "New in 2.0" list,
/// and the Seasoned Cast Iron "Try It" button.
@MainActor
final class AppWelcomeV2Tests: XCTestCase {

    private typealias Bullets = [AppWelcomeScreen.Bullet]

    private func bullets(themeOn: Bool = false, onTry: @escaping @MainActor @Sendable () -> Void = {}) -> Bullets {
        RootView.appWelcomeBullets(isSeasonedCastIronOn: themeOn, trySeasonedCastIron: onTry)
    }

    func test_listLeadsWithTheThemeAndItsTryItButton() {
        let list = bullets()
        XCTAssertEqual(
            list.map(\.title),
            [
                "Seasoned Cast Iron", "Hands-Free Voice", "Ask Dutch Oven Daddy", "Siri & Shortcuts", "And More",
            ]
        )
        XCTAssertEqual(Set(list.map(\.id)).count, list.count, "bullet ids must be unique")
        let action = try? XCTUnwrap(list.first?.action)
        XCTAssertEqual(action?.title, "Try It")
        XCTAssertEqual(action?.accessibilityIdentifier, RootView.appWelcomeTryThemeID)
        XCTAssertEqual(list.dropFirst().compactMap(\.action).count, 0, "only the theme bullet has a button")
    }

    func test_tryItReflectsTheCurrentTheme() {
        XCTAssertEqual(bullets(themeOn: false).first?.action?.isActive, false)
        XCTAssertEqual(bullets(themeOn: true).first?.action?.isActive, true)
        XCTAssertEqual(bullets(themeOn: true).first?.action?.activeTitle, "Selected")
    }

    func test_tryItRunsTheHandler() {
        let counter = TapCounter()
        let list = bullets(onTry: { counter.count += 1 })
        list.first?.action?.perform()
        XCTAssertEqual(counter.count, 1)
    }

    func test_copyFollowsTheHouseRules() {
        let copy =
            [RootView.appWelcomeIntro, RootView.appWelcomeSectionTitle]
            + bullets().flatMap { [$0.title, $0.description] }
        for line in copy {
            XCTAssertFalse(line.contains("\u{2014}"), "no em dashes in app copy: \(line)")
        }
        XCTAssertEqual(RootView.appWelcomeSectionTitle, "New in 2.0")
        // The intro summarizes the old five-bullet tour.
        for topic in ["recipes and articles", "favorites", "Cook Mode", "Heat Coach", "offline"] {
            XCTAssertTrue(RootView.appWelcomeIntro.contains(topic), "intro should mention \(topic)")
        }
    }
}

@MainActor
private final class TapCounter {
    var count = 0
}
