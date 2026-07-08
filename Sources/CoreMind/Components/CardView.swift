import SwiftUI

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

struct BrandCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.lg)
            .background(
                LinearGradient.brandSubtle
                    .overlay(Color.surfaceSecondary.opacity(0.7))
            )
            .cornerRadius(Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(LinearGradient.brand, lineWidth: 0.5)
            )
            .cardShadow()
    }
}
