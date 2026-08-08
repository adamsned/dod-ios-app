import DODDomain
import SwiftUI

/// Horizontal page-flip between recipes, the way you'd thumb through a magazine:
/// open a recipe from the feed and swipe left/right to land on the next/previous
/// one in the feed's order. No label, no setting — it's just how the detail
/// screen behaves when it was opened from an ordered list.
///
/// **Why a `TabView` page style.** It gives the native rubber-banding swipe +
/// snap for free, and it's backed by a paging controller that only materialises
/// the neighbouring pages — so even a long feed only ever has a couple of
/// `RecipeDetailView`s live at once. That laziness is safe here because
/// ``RecipeDetailViewModel``'s init is cheap (it just stores refs) and each
/// page's network load runs in the view's `.task`, firing only as that page
/// appears. Pages the user never swipes to never load.
///
/// The page content is injected: the App shell owns the (heavy) wiring of a
/// `RecipeDetailView` — dependencies, Cook Mode, Shopping List, Heat Coach — and
/// hands this a builder, so `DODFeatureRecipeDetail` stays free of that
/// composition (mirrors how `onSelectRelated` is injected rather than resolved
/// here). `isStart` is true only for the tapped recipe, so a Cook-Mode deep link
/// auto-starts on the page the user opened and not on the ones they swipe past.
public struct RecipeDetailPager<Page: View>: View {

    private let items: [RecipeListItem]
    private let startIndex: Int
    private let page: (_ item: RecipeListItem, _ isStart: Bool) -> Page

    @State private var selection: Int

    public init(
        items: [RecipeListItem],
        startIndex: Int,
        @ViewBuilder page: @escaping (_ item: RecipeListItem, _ isStart: Bool) -> Page
    ) {
        self.items = items
        // Clamp defensively: a stale start id resolves to the first page rather
        // than an out-of-range crash.
        self.startIndex = items.indices.contains(startIndex) ? startIndex : 0
        self.page = page
        self._selection = State(initialValue: items.indices.contains(startIndex) ? startIndex : 0)
    }

    public var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                page(item, index == startIndex)
                    .tag(index)
            }
        }
        #if os(iOS)
        // `.never` — no page dots. The swipe is meant to be felt, not signposted,
        // and dots would sit over the recipe content.
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
    }
}
