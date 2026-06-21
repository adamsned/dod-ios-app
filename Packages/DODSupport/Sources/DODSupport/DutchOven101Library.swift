import Foundation

/// A single beginner technique guide in the **Dutch Oven 101** library — a
/// short, read-it-before-you-cook lesson that turns a nervous beginner into a
/// capable cast-iron cook.
///
/// `TechniqueGuide` is a pure value type: a title, an honest read-time
/// estimate, an ordered list of ``Section`` lessons, and a handful of
/// ``keyTakeaways`` the reader can carry to the fire. It owns no UI and no
/// persistence — the "Learn" library screen renders these, and read-state
/// tracking is a later slice (see the spec note on US-52).
///
/// Why a value type and not a JSON resource: the v1 library is a curated,
/// bundled-in-code set (``DutchOven101Library``) of teacher-authored content.
/// A static array the compiler folds into a constant beats a runtime load +
/// parse for a small, human-readable, version-controlled table — the same
/// rationale as ``IngredientAisleClassifier``'s keyword map (CL-67) and
/// ``DutchOvenHeatCoach``'s structured reference content. It also means the
/// guides ship and test on the macOS slice ahead of any UI (CL-203).
///
/// Spec trace: US-52 / AC-52.1 (the content model + library core), CL-203,
/// T-809. Constitution §6 L1 mandate (every domain transform owns tests).
public struct TechniqueGuide: Identifiable, Sendable, Equatable {

    /// One ordered lesson within a guide — a heading and its prose body.
    ///
    /// Sections are rendered in array order; the body is plain text (no
    /// markup) so the UI owns all formatting decisions.
    public struct Section: Sendable, Equatable {

        /// Short title for the section (e.g. `"Why preheat at all?"`).
        public let heading: String

        /// The lesson prose. Plain text, one or more sentences.
        public let body: String

        /// Create a section from its heading and body.
        ///
        /// - Parameters:
        ///   - heading: Short section title.
        ///   - body: The lesson prose (plain text).
        public init(heading: String, body: String) {
            self.heading = heading
            self.body = body
        }
    }

    /// Stable, URL-safe identifier for the guide (e.g. `"preheating"`). Used
    /// as the ``Identifiable`` id, the ``DutchOven101Library/guide(slug:)``
    /// lookup key, and the future deep-link + read-state persistence key.
    public let slug: String

    /// Human-readable guide title (e.g. `"Preheating Your Dutch Oven"`).
    public let title: String

    /// Honest estimate of how long the guide takes to read, in minutes. Always
    /// positive; a beginner should know the time cost before committing.
    public let estimatedReadMinutes: Int

    /// The guide's ordered lessons. Two to four sections per guide.
    public let sections: [Section]

    /// Two to four one-line truths the reader carries to the fire — the
    /// "if you remember nothing else" distillation of the guide.
    public let keyTakeaways: [String]

    /// ``Identifiable`` conformance — the ``slug`` is the stable id.
    public var id: String { slug }

    /// Create a technique guide.
    ///
    /// - Parameters:
    ///   - slug: Stable, URL-safe identifier (also the ``id``).
    ///   - title: Human-readable guide title.
    ///   - estimatedReadMinutes: Honest read-time estimate in minutes.
    ///   - sections: Ordered lessons (two to four).
    ///   - keyTakeaways: One-line truths (two to four).
    public init(
        slug: String,
        title: String,
        estimatedReadMinutes: Int,
        sections: [Section],
        keyTakeaways: [String]
    ) {
        self.slug = slug
        self.title = title
        self.estimatedReadMinutes = estimatedReadMinutes
        self.sections = sections
        self.keyTakeaways = keyTakeaways
    }
}

/// The curated, bundled-in-code **Dutch Oven 101** beginner library — the
/// teaching that anchors the "Your First Cookout" keystone.
///
/// ``guides`` is a static, source-of-truth array of beginner technique guides
/// (Ned authors the content; this slice ships it as data). The library is pure
/// data with one convenience lookup, ``guide(slug:)`` — no UI, no network, no
/// persistence. The "Learn" library screen and per-guide read-state tracking
/// are later slices (US-52 spec note).
///
/// The guide bodies live in `DutchOven101Library+Content.swift` so neither
/// file crosses the 400-line SwiftLint cap; this file owns the public surface
/// and the slug lookup.
///
/// Spec trace: US-52 / AC-52.1, CL-203, T-809.
public enum DutchOven101Library {

    /// The full set of beginner technique guides, in recommended reading order
    /// (start by preheating; finish by adapting an indoor recipe outdoors).
    ///
    /// Backed by the per-guide constants in `DutchOven101Library+Content.swift`.
    public static let guides: [TechniqueGuide] = [
        preheatingGuide,
        lidOnLidOffGuide,
        brownThenBraiseGuide,
        restingMeatGuide,
        deglazingGuide,
        adaptingIndoorRecipesGuide,
    ]

    /// Look up a single guide by its ``TechniqueGuide/slug``.
    ///
    /// - Parameter slug: The stable identifier to find.
    /// - Returns: The matching guide, or `nil` when no guide has that slug.
    public static func guide(slug: String) -> TechniqueGuide? {
        guides.first { $0.slug == slug }
    }
}
