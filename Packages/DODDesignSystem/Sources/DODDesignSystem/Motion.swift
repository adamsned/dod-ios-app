import SwiftUI

/// v2 animation refresh — the single, shared interaction-motion vocabulary.
///
/// One spring curve and one press scale, reused everywhere, so every button in
/// the app presses with the exact same feel. This is deliberately tiny: the
/// refresh is about *consistency*, not variety. If a surface needs press
/// feedback, it reaches for these tokens (or ``DODPressableButtonStyle``) rather
/// than hand-rolling a `.scaleEffect` / `.spring` of its own.
///
/// Motion here is always additive polish: it changes press *feel* only, never
/// layout, size, or color. All of it is gated on Reduce Motion at the point of
/// use (``DODPressableButtonStyle`` does this internally), so a Reduce-Motion
/// user gets a calm, instant, still experience with haptics intact.
public enum DODMotion {

    /// The one press/response spring, reused across every pressable control.
    /// Snappy but soft: a quick settle with no visible wobble. Matches the
    /// brief's `.spring(response: 0.3, dampingFraction: 0.7)`.
    public static let press: Animation = .spring(response: 0.3, dampingFraction: 0.7)

    /// The scale a button label settles to while held. ~4% in — enough to feel
    /// responsive under the thumb, subtle enough to never read as bouncy.
    public static let pressedScale: CGFloat = 0.96
}

/// v2 animation refresh — a subtle, premium press-feedback button style.
///
/// While held, the label springs down to ``DODMotion/pressedScale`` on
/// ``DODMotion/press`` and settles back on release, with a single light impact
/// haptic on press-down. It renders `configuration.label` unchanged otherwise —
/// no fill, no padding, no color — so it layers onto existing icon / plain
/// buttons without altering their appearance or layout.
///
/// **Reduce Motion:** the scale is dropped entirely (the button stays perfectly
/// still), but the haptic is kept, so the interaction still confirms the tap.
/// This mirrors the app's existing `reduceMotion ? nil : …` gating convention.
///
/// Reach for it via ``SwiftUICore/ButtonStyle/dodPressable`` on plain / icon
/// buttons. It is *not* meant to replace a deliberate filled treatment
/// (`.dodProminentButton()` and friends already own their own press feel from
/// the system).
public struct DODPressableButtonStyle: ButtonStyle {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(isPressed: configuration.isPressed))
            .animation(reduceMotion ? nil : DODMotion.press, value: configuration.isPressed)
            // Light impact on press-down only (not on release), kept even under
            // Reduce Motion so the tap still registers physically.
            .sensoryFeedback(trigger: configuration.isPressed) { _, isPressed in
                isPressed ? .impact(weight: .light) : nil
            }
    }

    private func scale(isPressed: Bool) -> CGFloat {
        // Reduce Motion → never scale (instant, still); haptic still fires above.
        guard isPressed, !reduceMotion else { return 1 }
        return DODMotion.pressedScale
    }
}

extension ButtonStyle where Self == DODPressableButtonStyle {
    /// The shared v2 press-feedback style. See ``DODPressableButtonStyle``.
    public static var dodPressable: DODPressableButtonStyle { DODPressableButtonStyle() }
}

extension View {
    /// v2 animation refresh — the shared toggle-glyph transition: a clean
    /// SF Symbol `replace` crossfade when a glyph swaps between its two states
    /// (e.g. `bookmark` ↔ `bookmark.fill`, `pencil.tip.crop.circle` ↔ `.fill`).
    /// This is the same effect Cook Mode's play/pause uses; this helper just
    /// centralizes it and its Reduce-Motion gate.
    ///
    /// Reduce Motion → an instant, non-animated swap (`.identity`). Pass the
    /// call site's `\.accessibilityReduceMotion` environment value.
    public func dodSymbolReplace(reduceMotion: Bool) -> some View {
        contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
    }

    /// v2 animation refresh — a one-shot SF Symbol **bounce**, played each time
    /// `value` changes, as a small celebratory confirmation of a deliberate
    /// action (Save, Add to List, Download, Share…). Composes with
    /// ``dodSymbolReplace``: a glyph can fill AND bounce on the same tap.
    ///
    /// `direction` points the bounce the way the action moves — ``/up`` for
    /// send-y actions (Save, Share), ``/down`` for receive-y ones (Download) —
    /// so the motion *means* something rather than being decoration. Reduce
    /// Motion → no bounce (the underlying state still changes instantly).
    public func dodSymbolBounce(
        on value: some Equatable,
        direction: DODSymbolBounceDirection = .up,
        reduceMotion: Bool
    ) -> some View {
        modifier(DODSymbolBounceModifier(value: value, direction: direction, reduceMotion: reduceMotion))
    }
}

/// The direction an SF Symbol bounce travels — chosen to echo the action's own
/// motion. See ``SwiftUICore/View/dodSymbolBounce(on:direction:reduceMotion:)``.
public enum DODSymbolBounceDirection {
    /// Bounce up — for send-y / outbound actions (Save, Share).
    case up
    /// Bounce down — for receive-y / inbound actions (Download).
    case down
}

/// Backs ``SwiftUICore/View/dodSymbolBounce(on:direction:reduceMotion:)``. Gates
/// the discrete bounce on Reduce Motion at the point of use, mirroring
/// ``DODPressableButtonStyle`` and ``SwiftUICore/View/dodSymbolReplace(reduceMotion:)``.
private struct DODSymbolBounceModifier<Value: Equatable>: ViewModifier {

    let value: Value
    let direction: DODSymbolBounceDirection
    let reduceMotion: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            switch direction {
            case .up:
                content.symbolEffect(.bounce.up, value: value)
            case .down:
                content.symbolEffect(.bounce.down, value: value)
            }
        }
    }
}
