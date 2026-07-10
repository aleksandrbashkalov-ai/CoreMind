import SwiftUI

/// A subtle, flat card with rounded corners and shadow.
/// Use this as the default card style.
struct CardView<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(padding: CGFloat = Spacing.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(Color.surfaceSecondary)
            .cornerRadius(Radius.lg)
            .cardShadow()
    }
}

/// A card with a left accent stripe for emphasis.
/// Use for highlighted content (e.g., today's insight, featured item).
struct AccentCard<Content: View>: View {
    let accentColor: Color
    let content: Content

    init(accentColor: Color = .cmPrimary, @ViewBuilder content: () -> Content) {
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 3)

            content
                .padding(Spacing.lg)
        }
        .background(Color.surfaceSecondary)
        .cornerRadius(Radius.lg)
        .cardShadow()
    }
}

/// A bordered card with a subtle tinted background for secondary content.
/// Use for less prominent sections (e.g., stats, metadata).
struct MinimalCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.md)
            .background(Color.surfaceTertiary.opacity(0.3))
            .cornerRadius(Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.gray.opacity(0.08), lineWidth: 1)
            )
    }
}

/// A compact card for list items or entries.
/// Has no explicit padding so content determines size.
struct CompactCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.sm)
            .background(Color.surfaceSecondary)
            .cornerRadius(Radius.md)
            .cardShadow()
    }
}
