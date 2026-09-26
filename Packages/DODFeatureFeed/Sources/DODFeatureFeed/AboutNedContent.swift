import Foundation

/// About-page content translated from the live `dutchovendaddy.com/about-me/`
/// page (DUT-1330). Ships for v1 + v2. The site's "Navigating My Site",
/// "My Top Recipes", "Keep in Touch", and Subscribe / sidebar blocks are
/// intentionally omitted per spec.
///
/// Copy is embedded verbatim (not fetched) so it renders offline and is
/// pinned by L1 tests — a paraphrase trips CI rather than silently shipping.
/// The one deliberate normalization from the source: "cast iron and carbon
/// steel" (the site mid-sentence-capitalizes "Iron"/"Steel", an obvious typo).
/// Bullets / paragraphs carrying `[text](url)` render their links via
/// ``AboutNedView`` (inline markdown → tappable, opens in the browser).
enum AboutNedContent {

    // MARK: - Fun Facts about Me

    /// Verbatim, in site order. Some carry inline markdown links.
    static let funFacts: [String] = [
        "I live in Utah, where the Dutch Oven holds the title of the Official State Cooking Pot.",
        "I'm a [computer nerd](https://www.linkedin.com/in/nedadams/) during the day.",
        "I am one of three owners of [BuzzyWaxx](https://buzzywaxx.com/), the best cast iron and carbon steel seasoning product on the market if I do say so myself. 🙂",
        "The name of my blog came from some playful banter with my brother-in-law.",
        "My dad and I developed an [award-winning chili recipe](https://www.dutchovendaddy.com/dutch-oven-awesome-chili/) while I was still in high school.",
        "I have a food intolerance to fresh garlic, that's why a lot of my recipes use granulated garlic.",
        "My reputation with cast iron cooking has made me the go-to Dutch Oven Daddy in my area for all youth and scouting campouts.",
        "My family panics thinking I'm ill on the rare occasion I pull out the crockpot or a glass baking dish.",
        "My formative years were spent in Tennessee ([Go Vols](https://utsports.com/)), so I still feel like a Southern boy at heart, even after moving out west. You can take the boy out of the South, but you can't take the South out of the boy.",
        "I am the King of Dad Jokes… just ask our family eye doctor, who's had to see my family frequently due to the amount of eye rolling they do. And while we're on the topic, why did the scarecrow become a successful chef? Because he was outstanding in his field.",
    ]

    // MARK: - Publications

    /// Lead paragraphs with inline markdown links, in site order.
    static let publicationParagraphs: [String] = [
        "Living in Utah I have eaten my fair share of [Frog Eye Salad](https://www.foodandwine.com/what-is-frog-eye-salad-11844046) and was quoted in Food & Wine about the delicious recipe.",
        "Traveling Skillet Feature in [Southern Cast Iron Magazine](https://southerncastiron.com/), June 2020 Edition.",
        "Currently working with my amazing local butcher, [Heritage Craft Butchers](https://heritagecraftbutchers.com/) in Orem, Utah.",
    ]

    static let podcastsIntro = "I've been on several podcasts and you can listen to them here:"

    /// A titled row that opens an external link (podcasts).
    struct LinkRow: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let url: URL?
    }

    static let podcasts: [LinkRow] = [
        .init(
            title: "Happy Subscribers Podcast",
            detail: "April 7, 2026",
            url: URL(string: "https://open.spotify.com/episode/4jTHsvJpwFWIm6DMc4sojv")
        ),
        .init(
            title: "The BBQ Show",
            detail: "June 7, 2025",
            url: URL(string: "https://open.spotify.com/episode/7Fnh96LN4iWHX7VZ5BXuLh")
        ),
        .init(
            title: "Books Shows Tunes & Mad Acts",
            detail: "February 25, 2022",
            url: URL(
                string: "https://podcasts.apple.com/us/podcast/books-shows-tunes-mad-acts/id1448619722?i=1000552263901"
            )
        ),
        .init(
            title: "Hungry Squared Podcast",
            detail: "June 30, 2018",
            url: URL(
                string:
                    "https://www.hungrysquared.com/2018/06/ep99-cast-iron-history-seasoning-restoration-Dutch-Oven-Daddy-Ned-Adams.html"
            )
        ),
    ]

    // MARK: - Television Appearances & Events

    /// A photo card: a segment / event with an image and optional deep link.
    struct MediaFeature: Identifiable {
        let id = UUID()
        let imageName: String
        let title: String
        /// Show name, or "" for events with no broadcaster.
        let source: String
        let date: String
        let url: URL?
    }

    /// Photo mapping per Spencer (DUT-1330): outside/rock → Peach Dump Cake,
    /// gray quarter-zip → Manicotti, red quarter-zip → 7 Can Soup, pink
    /// "Who's Yer Daddy" shirt → Cherry Chocolate Cake.
    static let televisionAppearances: [MediaFeature] = [
        .init(
            imageName: "AboutPeachDumpCake",
            title: "Camp Oven Peach Dump Cake",
            source: "ABC4 Good Things Utah",
            date: "July 20, 2022",
            url: URL(string: "https://www.dutchovendaddy.com/peach-dump-cake/")
        ),
        .init(
            imageName: "AboutManicotti",
            title: "Dutch Oven Manicotti Pasta Bake",
            source: "Fox 13 The Place",
            date: "November 27, 2017",
            url: URL(string: "https://www.dutchovendaddy.com/manicotti-pasta-bake/")
        ),
        .init(
            imageName: "About7CanSoup",
            title: "Dutch Oven 7 Can Soup",
            source: "Fox 13 The Place",
            date: "September 26, 2018",
            url: URL(string: "https://www.dutchovendaddy.com/dutch-oven-7-can-soup/")
        ),
        .init(
            imageName: "AboutCherryChocolate",
            title: "Skillet Cherry Chocolate Cake",
            source: "Fox 13 The Place",
            date: "May 3, 2018",
            url: URL(string: "https://www.dutchovendaddy.com/cherry-chocolate-dump-cake/")
        ),
    ]

    static let events: [MediaFeature] = [
        .init(
            imageName: "AboutAlaska",
            title: "The Great Alaskan Cattle Drive",
            source: "",
            date: "July 4-10, 2021",
            url: nil
        )
    ]

    // MARK: - Frequently Asked Questions

    struct FAQ: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
    }

    static let faqs: [FAQ] = [
        .init(
            question: "Who is Dutch Oven Daddy?",
            answer:
                "Dutch Oven Daddy is Ned Adams, a cast iron cooking expert based in Utah. Ned has been featured on Fox 13, ABC4 Good Things Utah, and quoted in Food & Wine. He develops recipes, teaches cast iron cooking classes, and is a co-owner of BuzzyWaxx cast iron seasoning."
        ),
        .init(
            question: "What kind of cast iron does Ned use?",
            answer:
                "Ned cooks with a wide range of cast iron cookware including Dutch ovens, skillets, and camp ovens. He has a special appreciation for vintage pieces like Wagner Ware and uses his cookware for everything from weeknight dinners to outdoor campout cooking."
        ),
        .init(
            question: "Does Dutch Oven Daddy sell cast iron seasoning?",
            answer:
                "Yes. Ned is one of three co-owners of BuzzyWaxx, a cast iron and carbon steel seasoning product. You can find BuzzyWaxx in the Dutch Oven Daddy store and on Amazon."
        ),
        .init(
            question: "How does Dutch Oven Daddy develop recipes?",
            answer:
                "Every recipe on Dutch Oven Daddy is developed and tested in Ned's own kitchen. He photographs each step of the cooking process so readers can see exactly what to expect. Recipes are refined over multiple rounds before being published to the site."
        ),
    ]
}
