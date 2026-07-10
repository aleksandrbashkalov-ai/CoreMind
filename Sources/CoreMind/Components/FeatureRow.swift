import SwiftUI

struct FeatureRow<Content: View>: View {
    let icon: String
    let iconColor: Color
    let content: Content

    init(icon: String, iconColor: Color = .cmPrimary, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 20)

            content

            Spacer(minLength: Spacing.sm)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.textTertiary)
        }
        .contentShape(Rectangle())
        .hoverEffect()
    }
}

struct DividerWithLabel: View {
    let label: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            BrandDivider()
            Text(label)
                .smallFont()
                .foregroundColor(.textTertiary)
                .layoutPriority(1)
            BrandDivider()
        }
    }
}
