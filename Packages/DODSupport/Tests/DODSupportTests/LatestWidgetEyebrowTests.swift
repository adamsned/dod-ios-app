import Testing

@testable import DODSupport

/// `LatestWidgetEyebrowKind.resolve(isArticle:mode:)` backs the eyebrow /
/// accessibility-label copy on BOTH "Latest" widgets (home-screen
/// `FeaturedRecipeWidgetEntryView` + lock-screen
/// `LatestRecipeLockScreenWidgetEntryView`).
///
/// DUT-567 fixed the home-screen widget's `.recipes` eyebrow to key off the
/// resolved entry's own `isArticle` flag, because `LatestContent.entry(from:)`'s
/// `.recipes` case falls back to `entries.first` (which can be an article) when
/// the split classification scan found no recipe. Before this change, the
/// lock-screen widget's `.recipes` eyebrow ignored `isArticle` entirely and
/// hardcoded "Latest Recipe" — so in that exact fallback scenario the
/// lock-screen widget mislabeled an article as a recipe (both in its visible
/// eyebrow and its VoiceOver label, which reuses the same string) while the
/// home-screen widget correctly said "Latest Article." Routing both widgets
/// through this single resolver closes that drift at the root.
@Suite("LatestWidgetEyebrowKind.resolve")
struct LatestWidgetEyebrowKindResolveTests {

    @Test func autoModeKeysOffTheEntrysOwnKind() {
        #expect(LatestWidgetEyebrowKind.resolve(isArticle: false, mode: .auto) == .recipe)
        #expect(LatestWidgetEyebrowKind.resolve(isArticle: true, mode: .auto) == .article)
    }

    /// The regression case: `.recipes` mode must still say "article" when the
    /// resolved entry is one, because the `latestRecipe ?? entries.first`
    /// fallback in `LatestContent.entry(from:)` can hand it an article.
    @Test func recipesModeKeysOffTheEntrysOwnKindNotTheFixedMode() {
        #expect(LatestWidgetEyebrowKind.resolve(isArticle: false, mode: .recipes) == .recipe)
        #expect(LatestWidgetEyebrowKind.resolve(isArticle: true, mode: .recipes) == .article)
    }

    @Test func articlesModeIsAlwaysArticleRegardlessOfTheFlag() {
        #expect(LatestWidgetEyebrowKind.resolve(isArticle: false, mode: .articles) == .article)
        #expect(LatestWidgetEyebrowKind.resolve(isArticle: true, mode: .articles) == .article)
    }
}
