import Foundation
import StoreKit

enum SubscriptionTier: String, Codable, Sendable {
    case free = "Free"
    case pro = "Pro"

    var allowsUnlimitedJournaling: Bool { self == .pro }
    var allowsDeepAnalysis: Bool { self == .pro }
    var allowsWeeklyReports: Bool { self == .pro }
    var allowsImagePlayground: Bool { self == .pro }
    var allowsFocusModes: Bool { self == .pro }
    var allowsCalendarIntegration: Bool { self == .pro }
}

actor StoreManager: NSObject, StoreManagerProtocol {
    static let shared = StoreManager()

    private var products: [Product] = []
    private var purchasedProductIDs: Set<String> = []
    private var updatesTask: Task<Void, Never>?

    private let defaultsKey = "com.coremind.purchasedProducts"

    override init() {}

    func initialize() async {
        loadCachedEntitlements()
        await loadProducts()
        await verifyEntitlements()
        cacheEntitlements()
        startTransactionUpdates()
        Log.info("StoreManager initialized, tier: \(currentTier.rawValue)")
    }

    // MARK: - Testing Helpers

    func testing_setPurchased(id: String) {
        purchasedProductIDs.insert(id)
    }

    func testing_removePurchased(id: String) {
        purchasedProductIDs.remove(id)
    }

    var currentTier: SubscriptionTier {
        purchasedProductIDs.contains(ProProduct.monthly.rawValue) ||
        purchasedProductIDs.contains(ProProduct.yearly.rawValue) ||
        purchasedProductIDs.contains(ProProduct.lifetime.rawValue)
        ? .pro : .free
    }

    // MARK: - Real Prices

    func displayPrice(for product: ProProduct) async -> String? {
        products.first(where: { $0.id == product.rawValue })?.displayPrice
    }

    func storeProduct(for product: ProProduct) -> Product? {
        products.first(where: { $0.id == product.rawValue })
    }

    // MARK: - Private: Products

    private func loadProducts() async {
        do {
            let identifiers = Set(ProProduct.allCases.map { $0.rawValue })
            products = try await Product.products(for: identifiers)
        } catch {
            Log.error("Failed to load products: \(error.localizedDescription)")
        }
    }

    // MARK: - Private: Entitlements

    private func loadCachedEntitlements() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let ids = try? JSONDecoder().decode(Set<String>.self, from: data)
        else { return }
        purchasedProductIDs = ids
    }

    private func cacheEntitlements() {
        guard let data = try? JSONEncoder().encode(purchasedProductIDs) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func verifyEntitlements() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.revocationDate == nil {
                purchasedProductIDs.insert(transaction.productID)
            } else {
                purchasedProductIDs.remove(transaction.productID)
            }
        }
    }

    // MARK: - Private: Transaction Updates Listener

    private func startTransactionUpdates() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { break }
                guard case .verified(let transaction) = result else { continue }
                await self.handleTransactionUpdate(transaction)
            }
        }
    }

    private func handleTransactionUpdate(_ transaction: Transaction) async {
        if transaction.revocationDate == nil {
            purchasedProductIDs.insert(transaction.productID)
        } else {
            purchasedProductIDs.remove(transaction.productID)
        }
        cacheEntitlements()
        await transaction.finish()
    }

    // MARK: - Purchase / Restore

    func purchase(_ product: ProProduct) async throws {
        guard let product = products.first(where: { $0.id == product.rawValue }) else {
            throw StoreError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                purchasedProductIDs.insert(transaction.productID)
                cacheEntitlements()
                await transaction.finish()
            }
        case .userCancelled:
            throw StoreError.userCancelled
        case .pending:
            throw StoreError.pending
        @unknown default:
            throw StoreError.unknown
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await verifyEntitlements()
            cacheEntitlements()
        } catch {
            Log.error("Restore failed: \(error.localizedDescription)")
        }
    }
}

enum ProProduct: String, CaseIterable {
    case monthly = "com.coremind.pro.monthly"
    case yearly = "com.coremind.pro.yearly"
    case lifetime = "com.coremind.pro.lifetime"

    var displayPrice: String {
        switch self {
        case .monthly: return "$5.99/month"
        case .yearly: return "$49.99/year"
        case .lifetime: return "$99.99"
        }
    }

    var savingsNote: String? {
        switch self {
        case .yearly: return "Save 30% vs monthly"
        case .lifetime: return "One-time payment"
        case .monthly: return nil
        }
    }
}

enum StoreError: Error {
    case productNotFound
    case userCancelled
    case pending
    case unknown
}
