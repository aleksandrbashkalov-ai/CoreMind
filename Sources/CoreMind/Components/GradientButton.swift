import SwiftUI

struct GradientButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                }
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 8)
            .background(LinearGradient.brand)
            .cornerRadius(Radius.sm)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .captionFont()
                .foregroundColor(.brandPurple)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 6)
                .background(Color.brandPurple.opacity(0.08))
                .cornerRadius(Radius.sm)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
