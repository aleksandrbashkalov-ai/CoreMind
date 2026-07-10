import SwiftUI

// MARK: - Typography

/// Centralized text style sizes for Dynamic Type support.
enum Typography {
    static let headline: Font = .headline
    static let title: Font = .subheadline.weight(.medium)
    static let body: Font = .body
    static let caption: Font = .caption
    static let small: Font = .caption2
    static let timer: Font = .system(size: 44, weight: .medium, design: .monospaced)
}

// MARK: - Brand Colors — flat, distinctive, non-AI

/// CoreMind palette: warm, earthy, human — not generic purple/blue gradients.
/// Each color has a light and dark variant for proper Dark Mode support.
extension Color {
    // MARK: - Primary palette

    /// Warm indigo — our primary identity color. Replaces brandPurple.
    static let cmPrimary = Color(nsColor: AdaptiveColor.ns(
        light: (r: 92, g: 92, b: 231),
        dark: (r: 160, g: 160, b: 255)
    ))

    /// Warm teal — secondary, used for positive actions and highlights.
    static let cmTeal = Color(nsColor: AdaptiveColor.ns(
        light: (r: 0, g: 184, b: 148),
        dark: (r: 80, g: 220, b: 180)
    ))

    /// Earthy coral — energy, alerts, passion. Replaces statusRed as the warm accent.
    static let cmCoral = Color(nsColor: AdaptiveColor.ns(
        light: (r: 230, g: 92, b: 92),
        dark: (r: 255, g: 140, b: 120)
    ))

    /// Soft amber — warmth, creativity. Replaces statusOrange.
    static let cmAmber = Color(nsColor: AdaptiveColor.ns(
        light: (r: 220, g: 160, b: 40),
        dark: (r: 255, g: 200, b: 80)
    ))

    /// Deep slate — grounding, contrast.
    static let cmSlate = Color(nsColor: AdaptiveColor.ns(
        light: (r: 55, g: 65, b: 81),
        dark: (r: 200, g: 210, b: 225)
    ))

    // MARK: - Semantic aliases

    static let brandAccent = cmPrimary

    // MARK: - Surfaces (use system adaptive colors)

    static let surfacePrimary = Color(nsColor: .windowBackgroundColor)
    static let surfaceSecondary = Color(nsColor: .controlBackgroundColor)
    static let surfaceTertiary = Color(nsColor: .underPageBackgroundColor)

    // MARK: - Text

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    // MARK: - Status (keep vivid, but adjusted for harmony)

    static let statusGreen = Color(red: 38 / 255, green: 190 / 255, blue: 120 / 255)
    static let statusOrange = Color(red: 230 / 255, green: 155 / 255, blue: 35 / 255)
    static let statusRed = Color(red: 220 / 255, green: 70 / 255, blue: 60 / 255)
    static let statusTeal = Color(red: 30 / 255, green: 180 / 255, blue: 155 / 255)

    // MARK: - Selection state backgrounds

    static let selectedBg = Color.cmPrimary.opacity(0.12)
    static let borderPrimary = Color.cmPrimary.opacity(0.5)
}

// MARK: - Gradients (minimal — used only in TimerRing + 1 hero spot)

extension LinearGradient {
    /// Used ONLY for the timer ring accent.
    static let timerAccent = LinearGradient(
        colors: [.cmPrimary, .cmTeal],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Subtle shimmer for the hero welcome section.
    static let heroGlow = LinearGradient(
        colors: [.cmPrimary.opacity(0.08), .cmTeal.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Spacing

enum Spacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Corner Radius

enum Radius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let xl: CGFloat = 20
}

// MARK: - Shadow

extension View {
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Adaptive Color Helper

private enum AdaptiveColor {
    static func ns(
        light: (r: CGFloat, g: CGFloat, b: CGFloat),
        dark: (r: CGFloat, g: CGFloat, b: CGFloat)
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [
                .darkAqua, .vibrantDark,
                .accessibilityHighContrastDarkAqua,
                .accessibilityHighContrastVibrantDark
            ]) != nil
            let c = isDark ? dark : light
            return NSColor(red: c.r / 255, green: c.g / 255, blue: c.b / 255, alpha: 1)
        }
    }
}

// MARK: - Hover Effects (macOS HIG)

extension View {
    func hoverEffect() -> some View {
        modifier(HoverHighlightModifier())
    }
}

private struct HoverHighlightModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(Color.primary.opacity(isHovering ? 0.04 : 0))
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            .pointingHandCursor()
    }
}

// MARK: - Cursor Helper

extension View {
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursorModifier())
    }
}

private struct PointingHandCursorModifier: ViewModifier {
    @State private var cursorActive = false

    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering, !cursorActive {
                NSCursor.pointingHand.push()
                cursorActive = true
            } else if !hovering, cursorActive {
                NSCursor.pop()
                cursorActive = false
            }
        }
    }
}

// MARK: - Font Modifiers

extension View {
    func headlineFont() -> some View { font(.headline) }
    func titleFont() -> some View { font(.subheadline.weight(.medium)) }
    func bodyFont() -> some View { font(.body) }
    func captionFont() -> some View { font(.caption) }
    func smallFont() -> some View { font(.caption2) }
    func timerFont() -> some View { font(Typography.timer) }
}

// MARK: - Reduce Motion Helper

extension View {
    func conditionalAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(ReduceMotionModifier(animation: animation, value: value))
    }
}

private struct ReduceMotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation?
    let value: V

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.animation(animation, value: value)
        }
    }
}

// MARK: - Divider

struct BrandDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .frame(height: 1)
    }
}
