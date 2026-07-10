import SwiftUI

/// Primary action button — flat, filled, accessible.
/// Replaces the old gradient button with a clean solid-color design.
struct PrimaryButton: View {
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
            .background(Color.cmPrimary)
            .cornerRadius(Radius.sm)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Secondary ghost button — subtle, outline-style.
struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .captionFont()
                .foregroundColor(.cmPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 6)
                .background(Color.cmPrimary.opacity(0.08))
                .cornerRadius(Radius.sm)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
