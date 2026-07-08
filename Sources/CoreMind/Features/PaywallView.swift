import SwiftUI

// MARK: - URLs

private let termsURL = "https://coremind.app/terms"
private let privacyURL = "https://coremind.app/privacy"

struct PaywallView: View {
    @Environment(\.deps) var deps
    @State private var selectedProduct: ProProduct = .yearly
    @State private var isPurchasing = false
    @State private var isPro = false
    @State private var isLoading = true
    @State private var restoreMessage: String?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var productPrices: [ProProduct: String] = [:]

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: Spacing.md) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading…")
                        .captionFont()
                        .foregroundColor(.textTertiary)
                }
                .frame(width: 360, height: 560)
                .accessibilityLabel("Loading CoreMind Pro")
            } else if isPro {
                proAlreadyView
            } else {
                paywallContent
            }
        }
        .background(Color.surfacePrimary)
        .task {
            await loadPrices()
            let tier = await deps.storeManager.currentTier
            isPro = (tier == .pro)
            isLoading = false
        }
        .alert("Purchase Error", isPresented: $showError, actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "An unexpected error occurred.")
        })
    }

    // MARK: - Load Real Prices

    private func loadPrices() async {
        for product in ProProduct.allCases {
            if let price = await deps.storeManager.displayPrice(for: product) {
                productPrices[product] = price
            }
        }
    }

    // MARK: - Already Pro

    private var proAlreadyView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                Spacer().frame(height: Spacing.md)

                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(LinearGradient.brandVertical)
                    .accessibilityHidden(true)

                Text("You're Pro!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(LinearGradient.brandVertical)
                    .accessibilityAddTraits(.isHeader)

                Text("Thank you for supporting CoreMind. All Pro features are unlocked.")
                    .captionFont()
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)

                BrandDivider()

                comparisonTable

                Spacer()

                footnotes
            }
            .padding()
        }
        .frame(width: 360, height: 560)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Paywall Content

    private var paywallContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.xl) {
                heroSection
                BrandDivider()
                comparisonTable
                BrandDivider()
                pricingSection
                purchaseButton
                restoreButton
                footnotes
            }
            .padding()
        }
        .frame(width: 360, height: 560)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 36))
                .foregroundStyle(LinearGradient.brandVertical)
                .accessibilityHidden(true)

            Text("CoreMind Pro")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(LinearGradient.brandVertical)
                .accessibilityAddTraits(.isHeader)

            Text("Unlock your full potential with AI-powered coaching, unlimited journaling, and deep insights.")
                .captionFont()
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Comparison

    private var comparisonTable: some View {
        VStack(spacing: Spacing.sm) {
            Text("Free vs Pro")
                .titleFont()
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            ForEach(FeatureComparison.allCases, id: \.rawValue) { feature in
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(feature.rawValue)
                            .bodyFont()
                            .fontWeight(.medium)
                        if let note = feature.note {
                            Text(note)
                                .smallFont()
                                .foregroundColor(.textTertiary)
                        }
                    }
                    Spacer()
                    HStack(spacing: Spacing.lg) {
                        Image(systemName: feature.free ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(feature.free ? .statusGreen : .textTertiary)
                            .font(.caption)
                            .accessibilityHidden(true)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.brandPurple)
                            .font(.caption)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.vertical, Spacing.xxs)
                .accessibilityLabel("\(feature.rawValue): \(feature.free ? "Free" : "Paid only") — Pro")
                if feature != FeatureComparison.allCases.last {
                    BrandDivider()
                }
            }
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: Spacing.sm) {
            Text("Choose Your Plan")
                .titleFont()
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: Spacing.sm) {
                ForEach(ProProduct.allCases, id: \.rawValue) { product in
                    Button(action: { selectedProduct = product }) {
                        VStack(spacing: Spacing.xxs) {
                            Text(product.label)
                                .smallFont()
                                .fontWeight(.medium)
                            Text(displayPrice(for: product))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(LinearGradient.brandVertical)
                            if let note = product.note {
                                Text(note)
                                    .smallFont()
                                    .foregroundColor(.statusGreen)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .padding(.horizontal, Spacing.xs)
                        .background(
                            Group {
                                if selectedProduct == product {
                                    LinearGradient.brandSubtle
                                } else {
                                    Color.surfaceSecondary
                                }
                            }
                        )
                        .cornerRadius(Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(selectedProduct == product ? Color.brandPurple : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(product.label) plan: \(displayPrice(for: product))\(product.note.map { ". \($0)" } ?? "")")
                    .accessibilityAddTraits(selectedProduct == product ? [.isSelected] : [])
                }
            }
        }
    }

    private func displayPrice(for product: ProProduct) -> String {
        productPrices[product] ?? product.fallbackPrice
    }

    // MARK: - Purchase

    private var purchaseButton: some View {
        GradientButton(title: "Continue with \(selectedProduct.label)", icon: "crown.fill") {
            Task { await purchase() }
        }
        .disabled(isPurchasing)
        .overlay {
            if isPurchasing {
                ProgressView().scaleEffect(0.6)
            }
        }
        .accessibilityHint("Purchase the \(selectedProduct.label) plan")
    }

    private var restoreButton: some View {
        VStack(spacing: Spacing.xxs) {
            Button("Restore Purchases") {
                Task { await restore() }
            }
            .buttonStyle(.plain)
            .captionFont()
            .foregroundColor(.brandPurple)
            .accessibilityHint("Restores previously purchased Pro subscription")

            if let msg = restoreMessage {
                Text(msg)
                    .smallFont()
                    .foregroundColor(.textTertiary)
                    .accessibilityLabel("Restore status: \(msg)")
            }
        }
    }

    private var footnotes: some View {
        HStack(spacing: Spacing.md) {
            if let url = URL(string: termsURL) {
                Link("Terms of Service", destination: url)
                    .smallFont()
                    .foregroundColor(.textTertiary)
            }
            if let url = URL(string: privacyURL) {
                Link("Privacy Policy", destination: url)
                    .smallFont()
                    .foregroundColor(.textTertiary)
            }
        }
    }

    // MARK: - Actions

    private func purchase() async {
        isPurchasing = true
        do {
            try await deps.storeManager.purchase(selectedProduct)
            isPro = true
        } catch StoreError.userCancelled {
            // no-op
        } catch StoreError.pending {
            restoreMessage = "Your purchase is pending. It will complete shortly."
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            Log.error("Purchase failed: \(error.localizedDescription)")
        }
        isPurchasing = false
    }

    private func restore() async {
        await deps.storeManager.restorePurchases()
        let tier = await deps.storeManager.currentTier
        if tier == .pro {
            isPro = true
            restoreMessage = "Your Pro subscription has been restored."
        } else {
            restoreMessage = "No purchases found. If you expected to find something, check your App Store account."
        }
    }
}

// MARK: - Feature Comparison

enum FeatureComparison: String, CaseIterable {
    case journaling = "Journaling"
    case checkIns = "Mood & Energy Check-ins"
    case dailyWisdom = "Daily Stoic Wisdom"
    case focusSessions = "Focus Sessions"
    case breathing = "Breathing Exercises"
    case aICoaching = "AI Coaching Insights"
    case weeklyReports = "Weekly Reports"
    case imagePlayground = "Image Playground"
    case calendarIntegration = "Calendar Integration"

    var free: Bool {
        switch self {
        case .journaling, .checkIns, .dailyWisdom, .focusSessions, .breathing:
            return true
        case .aICoaching, .weeklyReports, .imagePlayground, .calendarIntegration:
            return false
        }
    }

    var note: String? {
        switch self {
        case .journaling: return "5 entries/mo"
        case .aICoaching: return nil
        case .imagePlayground: return "macOS 27+"
        default: return nil
        }
    }
}

// MARK: - Pro Product Display

extension ProProduct {
    var label: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }

    /// Hardcoded fallback price when StoreKit products are unavailable.
    var fallbackPrice: String {
        switch self {
        case .monthly: return "$5.99"
        case .yearly: return "$49.99"
        case .lifetime: return "$99.99"
        }
    }

    var note: String? {
        switch self {
        case .yearly: return "Best value"
        case .lifetime: return "One-time"
        case .monthly: return nil
        }
    }
}
