#if canImport(UIKit)
import DODDomain
import Foundation
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@testable import DODFeatureRecipeDetail

/// L4 visual-regression coverage for ``ArticleDetailView`` (US-37 / CL-63 /
/// AC-37.7 / T-640).
///
/// Pins the article-detail layout in light + dark on iPhone 13 baseline at
/// default Dynamic Type. The article surface is intentionally minimal —
/// hero + title + published-date caption + sanitized body — so two
/// baselines are sufficient for v1; richer Dynamic Type / iPad coverage
/// can layer on if user signal emerges.
///
/// First run with `isRecording = false` to create baselines, then revert
/// and commit. Subsequent runs diff against the baselines.
///
/// Spec trace: constitution §6 L4, US-37 / AC-37.7.
final class ArticleDetailViewSnapshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Flip to true locally to refresh baselines after an intentional
        // visual change, then revert before commit.
        isRecording = false
    }

    @MainActor
    func test_articleDetailView_light() {
        assertArticle(dark: false)
    }

    @MainActor
    func test_articleDetailView_dark() {
        assertArticle(dark: true)
    }

    // MARK: - Helpers

    @MainActor
    private func assertArticle(
        dark: Bool,
        file: StaticString = #file,
        testName: String = #function,
        line: UInt = #line
    ) {
        let article = Self.makeArticleFixture()
        let view = ArticleDetailView(recipe: article)
            .frame(width: 390, height: 844)
            .preferredColorScheme(dark ? .dark : .light)
        assertSnapshot(
            of: view,
            as: .image(
                layout: .device(config: .iPhone13),
                traits: UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
            ),
            file: file,
            testName: testName,
            line: line
        )
    }

    /// Article fixture with a stable id + title + body so the snapshots
    /// don't drift between runs. The body text mirrors the kind of
    /// roundup-post content CL-63 calls out (Spencer's example:
    /// "Best Dutch Oven Recipes (30+ Tried and Tested Favorites)").
    static func makeArticleFixture() -> Recipe {
        Recipe(
            id: 9001,
            slug: "best-dutch-oven-recipes",
            title: "Best Dutch Oven Recipes (30+ Tried and Tested Favorites)",
            excerpt: "Our favorite cast-iron classics.",
            canonicalURL: URL(string: "https://www.dutchovendaddy.com/best-dutch-oven-recipes/")
                ?? URL(filePath: "/"),
            heroImage: nil,
            heroImageLargeURL: nil,
            categoryIDs: [],
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            kind: .article,
            articleBodyHTML: """
                Welcome to my favorite roundup of dutch oven recipes. Over the last \
                several years I've been cooking and testing every recipe I can find \
                in my cast iron. This is the cream of the crop.

                From hearty stews and braises to fresh-baked breads, these are the \
                dishes I come back to every week. Every recipe on this list has \
                been cooked at least three times in my own kitchen — no \
                cookbook-throwaway recipes, just the ones that earn the space \
                on my stove top.

                Whether you're new to dutch oven cooking or you've been at it for \
                years, I hope you find a new favorite in this collection.
                """
        )
    }
}
#endif
