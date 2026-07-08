import SwiftUI

// MARK: - Typography Constants

/// Centralized text style sizes for HIG-compliant Dynamic Type support.
/// All feature views use these instead of hardcoded sizes.
enum Typography {
    /// `.headline` — semibold, ~13–15pt (adapts to user text size)
    static let headline: Font = .headline
    /// `.subheadline.weight(.medium)` — ~11–12pt
    static let title: Font = .subheadline.weight(.medium)
    /// `.body` — ~12–13pt
    static let body: Font = .body
    /// `.caption` — ~11–12pt
    static let caption: Font = .caption
    /// `.caption2` — ~11pt, lighter weight
    static let small: Font = .caption2
    /// Large monospaced for timer display (timerFont stays large intentionally)
    static let timer: Font = .system(size: 44, weight: .medium, design: .monospaced)
}

// MARK: - Brand Colors (Dark Mode Adaptive)

private enum AdaptiveColor {
    static func ns(_ light: (r: CGFloat, g: CGFloat, b: CGFloat), dark: (r: CGFloat, g: CGFloat, b: CGFloat)) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark]) != nil
            let c = isDark ? dark : light
            return NSColor(red: c.r / 255, green: c.g / 255, blue: c.b / 255, alpha: 1)
        }
    }
}

extension Color {
    /// Brand purple — automatically adapts for Dark Mode (lighter in dark)
    static let brandPurple = Color(nsColor: AdaptiveColor.ns(
        (r: 108, g: 92, b: 231),
        dark: (r: 170, g: 155, b: 255)
    ))
    /// Brand blue — automatically adapts for Dark Mode (lighter in dark)
    static let brandBlue = Color(nsColor: AdaptiveColor.ns(
        (r: 74, g: 144, b: 217),
        dark: (r: 120, g: 190, b: 250)
    ))
    static let brandGradientStart = brandPurple
    static let brandGradientEnd = brandBlue

    // MARK: - Surfaces (adaptive via NSColor)

    /// Window background — adapts to Dark Mode natively
    static let surfacePrimary = Color(nsColor: .windowBackgroundColor)
    /// Control background — adapts to Dark Mode natively
    static let surfaceSecondary = Color(nsColor: .controlBackgroundColor)
    /// Under-page background — adapts to Dark Mode natively
    static let surfaceTertiary = Color(nsColor: .underPageBackgroundColor)

    // MARK: - Text Colors (adaptive via platform colors)

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    /// Uses `tertiaryLabelColor` for proper Dark Mode + accessibility contrast
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    // MARK: - Status Colors (keep vivid in both modes)

    static let statusGreen = Color(red: 46 / 255, green: 204 / 255, blue: 113 / 255)
    static let statusOrange = Color(red: 243 / 255, green: 156 / 255, blue: 18 / 255)
    static let statusRed = Color(red: 231 / 255, green: 76 / 255, blue: 60 / 255)
    static let statusTeal = Color(red: 26 / 255, green: 188 / 255, blue: 156 / 255)
}

// MARK: - Gradients

extension LinearGradient {
    static let brand = LinearGradient(
        colors: [.brandPurple, .brandBlue],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let brandVertical = LinearGradient(
        colors: [.brandPurple, .brandBlue],
        startPoint: .top,
        endPoint: .bottom
    )

    static let brandSubtle = LinearGradient(
        colors: [.brandPurple.opacity(0.1), .brandBlue.opacity(0.1)],
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

// MARK: - Hover Effects (macOS HIG)

/// Adds a macOS-appropriate hover highlight and pointing-hand cursor.
/// Use on any tappable plain-style button or card that needs hover feedback.
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
                    .fill(Color.primary.opacity(isHovering ? 0.06 : 0))
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            .pointingHandCursor()
    }
}

// MARK: - Cursor Helpers (macOS)

/// Adds a pointing-hand cursor on hover. Uses addCursorRect for safe cursor management.
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

// MARK: - Font Modifiers (Dynamic Type)

extension View {
    /// Uses `.headline` — responds to system text size settings.
    func headlineFont() -> some View {
        font(.headline)
    }

    /// Uses `.subheadline.weight(.medium)` — responds to system text size settings.
    func titleFont() -> some View {
        font(.subheadline.weight(.medium))
    }

    /// Uses `.body` — responds to system text size settings.
    func bodyFont() -> some View {
        font(.body)
    }

    /// Uses `.caption` — responds to system text size settings.
    func captionFont() -> some View {
        font(.caption)
    }

    /// Uses `.caption2` — responds to system text size settings.
    func smallFont() -> some View {
        font(.caption2)
    }

    /// Large monospaced timer — intentionally fixed size for readability.
    func timerFont() -> some View {
        font(Typography.timer)
    }
}

// MARK: - Reduce Motion

/// Applies an animation only when the user has not requested Reduce Motion.
/// Use this everywhere instead of `.animation(_, value:)` directly.
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
            .fill(Color.gray.opacity(0.12))
            .frame(height: 1)
    }
}
