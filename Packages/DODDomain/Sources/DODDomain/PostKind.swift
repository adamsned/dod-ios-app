import Foundation

/// Discriminator for the two flavors of post the app surfaces from
/// dutchovendaddy.com:
///
/// - ``recipe``: the post page carries a parseable JSON-LD `@type: Recipe`
///   block (per CL-1 / AC-4.11). The detail screen renders ingredients,
///   instructions, times, nutrition, video, Cook Mode CTA, related
///   recipes, ratings, comments — the full recipe surface.
/// - ``article``: the post page lacks a parseable JSON-LD `@type: Recipe`
///   block (per CL-63 / US-37 / AC-37.2 — most commonly a roundup post,
///   like "Best Dutch Oven Recipes (30+ Tried and Tested Favorites)"),
///   but the article body extracts cleanly from the rendered HTML page.
///   The detail screen renders the hero + title + sanitized HTML body
///   only — no ingredients section, no Cook Mode CTA, no servings
///   stepper, no ratings / comments, no related strip.
///
/// The kind is surfaced on the existing ``Recipe`` domain type via the
/// ``Recipe/kind`` property rather than introducing a separate `Article`
/// domain type — see CL-63 decision 3 for the trade-off (the list-row
/// presentation is identical for both kinds, and splitting the domain
/// would force every list surface to discriminate; the kind difference
/// matters only on the detail screen).
///
/// Spec trace: US-37, CL-63, AC-37.2.
public enum PostKind: String, Sendable, Hashable, Codable {
    case recipe
    case article
}
