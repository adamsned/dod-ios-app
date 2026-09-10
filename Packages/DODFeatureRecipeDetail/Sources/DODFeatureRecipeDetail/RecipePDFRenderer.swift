#if os(iOS) && canImport(UIKit)
import DODDomain
import UIKit

/// Renders a recipe to a print-ready PDF (DUT-1324).
///
/// Design (Spencer's spec):
/// - **Always white background**, independent of light/dark mode — saves printer
///   ink. Colors here are fixed literals, deliberately NOT `DODColor` (which
///   flips in dark).
/// - **Header:** the hero photo across the top with the DOD logo badge tucked in
///   its corner, then the title.
/// - **Ingredients:** each line preceded by an empty **bubble** the cook can tick
///   off by hand on the printed sheet.
/// - **Instructions:** website-style — the step number in a **burnt-orange disc**,
///   the step text beside it, at a comfortable reading size.
///
/// Text is drawn as vector `NSAttributedString` (not rasterized) so print stays
/// crisp and selectable, and the content paginates onto US Letter pages.
///
/// The caller passes an already **scaled + unit-converted** `Recipe` (see
/// `RecipeDetailView.recipePDFData`) so the printout matches what's on screen.
public struct RecipePDFRenderer {

    public init() {}

    // US Letter at 72 pt/inch.
    private let pageSize = CGSize(width: 612, height: 792)
    private let margin: CGFloat = 48

    // Fixed print colors (see type doc — never DODColor).
    private let ink = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1)
    private let subtle = UIColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1)
    private let orange = UIColor(red: 197 / 255, green: 106 / 255, blue: 36 / 255, alpha: 1)
    private let bubbleStroke = UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1)
    private let hairline = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)

    /// Render `recipe` to PDF bytes. `heroImage` / `logo` are optional — the
    /// header degrades gracefully when either is missing.
    public func pdfData(recipe: Recipe, heroImage: UIImage?, logo: UIImage?) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { rendererCtx in
            var layout = Layout(ctx: rendererCtx, page: pageSize, margin: margin)
            layout.beginPage()
            drawHeader(recipe: recipe, heroImage: heroImage, logo: logo, layout: &layout)

            if !recipe.ingredients.isEmpty {
                drawSectionHeader("Ingredients", layout: &layout)
                for ingredient in recipe.ingredients {
                    drawIngredient(ingredient.text, layout: &layout)
                }
                layout.advance(DODPDFMetrics.sectionGap)
            }

            if !recipe.instructions.isEmpty {
                drawSectionHeader("Instructions", layout: &layout)
                for step in recipe.instructions.sorted(by: { $0.step < $1.step }) {
                    drawStep(number: step.step, text: step.text, layout: &layout)
                }
            }
        }
    }

    // MARK: - Header

    private func drawHeader(recipe: Recipe, heroImage: UIImage?, logo: UIImage?, layout: inout Layout) {
        let cw = layout.contentWidth
        let cg = layout.ctx.cgContext

        if let heroImage {
            let box = CGRect(x: layout.left, y: layout.y, width: cw, height: DODPDFMetrics.heroHeight)
            let clip = UIBezierPath(roundedRect: box, cornerRadius: 12)
            cg.saveGState()
            clip.addClip()
            drawAspectFill(heroImage, in: box)
            cg.restoreGState()
            drawLogoBadge(logo, inCornerOf: box, cg: cg)
            layout.advance(DODPDFMetrics.heroHeight + 16)
        } else if let logo {
            // No photo — still badge the page, top-right.
            let size: CGFloat = 48
            logo.draw(in: CGRect(x: layout.left + cw - size, y: layout.y, width: size, height: size))
        }

        let titleHeight = drawWrapped(
            recipe.title,
            font: .systemFont(ofSize: 24, weight: .bold),
            color: ink,
            at: CGPoint(x: layout.left, y: layout.y),
            width: cw
        )
        layout.advance(titleHeight + 6)

        if let subtitle = headerSubtitle(for: recipe) {
            let subtitleHeight = drawWrapped(
                subtitle,
                font: .systemFont(ofSize: 12, weight: .regular),
                color: subtle,
                at: CGPoint(x: layout.left, y: layout.y),
                width: cw
            )
            layout.advance(subtitleHeight + 10)
        } else {
            layout.advance(6)
        }

        drawHairline(&layout)
        layout.advance(14)
    }

    /// The logo badge in the hero's top-right corner, on a white disc so it
    /// reads over any photo.
    private func drawLogoBadge(_ logo: UIImage?, inCornerOf box: CGRect, cg: CGContext) {
        guard let logo else { return }
        let size: CGFloat = 52
        let inset: CGFloat = 12
        let center = CGPoint(x: box.maxX - inset - size / 2, y: box.minY + inset + size / 2)
        let backing = CGRect(x: center.x - size / 2 - 4, y: center.y - size / 2 - 4, width: size + 8, height: size + 8)
        UIColor.white.setFill()
        cg.fillEllipse(in: backing)
        logo.draw(in: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size))
    }

    /// A compact "Serves N · Total 45 min" line when the data is present.
    private func headerSubtitle(for recipe: Recipe) -> String? {
        var parts: [String] = []
        if let servings = recipe.servings, servings > 0 {
            parts.append("Serves \(servings)")
        }
        if let total = recipe.totalTime, total > .zero {
            let minutes = Int(total.components.seconds / 60)
            if minutes > 0 { parts.append("Total \(minutes) min") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }

    // MARK: - Sections

    private func drawSectionHeader(_ title: String, layout: inout Layout) {
        let font = UIFont.systemFont(ofSize: 18, weight: .bold)
        let height = measure(title, font: font, width: layout.contentWidth)
        layout.ensure(height + 22)
        drawWrapped(
            title,
            font: font,
            color: ink,
            at: CGPoint(x: layout.left, y: layout.y),
            width: layout.contentWidth
        )
        layout.advance(height + 6)
        drawHairline(&layout)
        layout.advance(10)
    }

    private func drawIngredient(_ text: String, layout: inout Layout) {
        let bubble: CGFloat = 15
        let gap: CGFloat = 12
        let textX = layout.left + bubble + gap
        let textW = layout.contentWidth - bubble - gap
        let font = UIFont.systemFont(ofSize: 14)
        let textH = measure(text, font: font, width: textW)
        let rowH = max(textH, font.lineHeight) + 12
        layout.ensure(rowH)

        let cg = layout.ctx.cgContext
        let firstLineCenterY = layout.y + font.lineHeight / 2
        let bubbleRect = CGRect(x: layout.left, y: firstLineCenterY - bubble / 2, width: bubble, height: bubble)
        cg.setStrokeColor(bubbleStroke.cgColor)
        cg.setLineWidth(1.3)
        cg.strokeEllipse(in: bubbleRect)

        drawWrapped(text, font: font, color: ink, at: CGPoint(x: textX, y: layout.y), width: textW)
        layout.advance(rowH)
    }

    private func drawStep(number: Int, text: String, layout: inout Layout) {
        let disc: CGFloat = 26
        let gap: CGFloat = 14
        let textX = layout.left + disc + gap
        let textW = layout.contentWidth - disc - gap
        let font = UIFont.systemFont(ofSize: 15)
        let textH = measure(text, font: font, width: textW)
        let rowH = max(textH, disc) + 16
        layout.ensure(rowH)

        let cg = layout.ctx.cgContext
        let discRect = CGRect(x: layout.left, y: layout.y, width: disc, height: disc)
        orange.setFill()
        cg.fillEllipse(in: discRect)
        let numberString = NSAttributedString(
            string: "\(number)",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: UIColor.white,
            ]
        )
        let numberSize = numberString.size()
        numberString.draw(
            at: CGPoint(x: discRect.midX - numberSize.width / 2, y: discRect.midY - numberSize.height / 2)
        )

        drawWrapped(text, font: font, color: ink, at: CGPoint(x: textX, y: layout.y), width: textW)
        layout.advance(rowH)
    }

    // MARK: - Drawing primitives

    /// Aspect-fill `image` into `box` (center-crop). Caller sets any clip. Draws
    /// into the current UIKit graphics context (the PDF page).
    private func drawAspectFill(_ image: UIImage, in box: CGRect) {
        let iw = image.size.width
        let ih = image.size.height
        guard iw > 0, ih > 0 else { return }
        let scale = max(box.width / iw, box.height / ih)
        let dw = iw * scale
        let dh = ih * scale
        image.draw(in: CGRect(x: box.midX - dw / 2, y: box.midY - dh / 2, width: dw, height: dh))
    }

    /// Draw wrapped text at `origin` in `width`; returns the height consumed.
    /// Draws into the current graphics context (set by the PDF render block).
    @discardableResult
    private func drawWrapped(
        _ text: String,
        font: UIFont,
        color: UIColor,
        at origin: CGPoint,
        width: CGFloat
    ) -> CGFloat {
        let attr = attributed(text, font: font, color: color)
        let height = ceil(
            attr.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).height
        )
        attr.draw(
            with: CGRect(x: origin.x, y: origin.y, width: width, height: height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return height
    }

    private func measure(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        ceil(
            attributed(text, font: font, color: ink).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).height
        )
    }

    private func attributed(_ text: String, font: UIFont, color: UIColor) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 2
        return NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        )
    }

    private func drawHairline(_ layout: inout Layout) {
        let cg = layout.ctx.cgContext
        cg.setStrokeColor(hairline.cgColor)
        cg.setLineWidth(1)
        cg.move(to: CGPoint(x: layout.left, y: layout.y))
        cg.addLine(to: CGPoint(x: layout.left + layout.contentWidth, y: layout.y))
        cg.strokePath()
    }

    /// Cursor + pagination for the running page. Fills each fresh page white and
    /// starts a new page when a row wouldn't fit, so nothing clips.
    private struct Layout {
        let ctx: UIGraphicsPDFRendererContext
        let page: CGSize
        let margin: CGFloat
        var y: CGFloat = 0

        var left: CGFloat { margin }
        var contentWidth: CGFloat { page.width - margin * 2 }
        var pageBottom: CGFloat { page.height - margin }

        mutating func beginPage() {
            ctx.beginPage()
            UIColor.white.setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: page))
            y = margin
        }

        /// Start a new page if `height` wouldn't fit below the cursor.
        mutating func ensure(_ height: CGFloat) {
            if y + height > pageBottom { beginPage() }
        }

        mutating func advance(_ dy: CGFloat) { y += dy }
    }
}

/// Shared spacing so the renderer body stays readable.
private enum DODPDFMetrics {
    static let heroHeight: CGFloat = 200
    static let sectionGap: CGFloat = 18
}
#endif
