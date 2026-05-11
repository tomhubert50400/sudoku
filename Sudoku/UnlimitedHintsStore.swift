import Foundation
import StoreKit

enum UnlimitedHintsPurchaseError: LocalizedError {
    case productUnavailable
    case pending
    case unverified

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            L10n.text("purchase.unlimited_hints.unavailable")
        case .pending:
            L10n.text("purchase.unlimited_hints.pending")
        case .unverified:
            L10n.text("purchase.unlimited_hints.unverified")
        }
    }
}

@MainActor
final class UnlimitedHintsStore: ObservableObject {
    static let productID = "com.tomhubert.Sudoku.unlimitedHints"

    @Published private(set) var product: Product?
    @Published private(set) var isUnlocked = false
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var lastErrorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    var displayPrice: String {
        product?.displayPrice ?? L10n.text("purchase.unlimited_hints.default_price")
    }

    init() {
        transactionUpdatesTask = listenForTransactions()
        Task {
            await refreshPurchasedStatus()
            await loadProduct()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func loadProduct() async {
        guard product == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            product = try await Product.products(for: [Self.productID]).first
            if product == nil {
                lastErrorMessage = UnlimitedHintsPurchaseError.productUnavailable.localizedDescription
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func purchase() async -> Bool {
        if isUnlocked { return true }

        if product == nil {
            await loadProduct()
        }

        guard let product else {
            lastErrorMessage = UnlimitedHintsPurchaseError.productUnavailable.localizedDescription
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                guard transaction.productID == Self.productID else { return false }
                isUnlocked = true
                lastErrorMessage = nil
                await transaction.finish()
                return true
            case .pending:
                lastErrorMessage = UnlimitedHintsPurchaseError.pending.localizedDescription
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async -> Bool {
        do {
            try await AppStore.sync()
            await refreshPurchasedStatus()
            return isUnlocked
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    func refreshPurchasedStatus() async {
        var hasEntitlement = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            if transaction.productID == Self.productID {
                hasEntitlement = true
                break
            }
        }

        isUnlocked = hasEntitlement
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let transaction = try? Self.checkVerified(result) else { continue }
                guard transaction.productID == Self.productID else {
                    await transaction.finish()
                    continue
                }

                await MainActor.run {
                    self?.isUnlocked = true
                    self?.lastErrorMessage = nil
                }
                await transaction.finish()
            }
        }
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            safe
        case .unverified:
            throw UnlimitedHintsPurchaseError.unverified
        }
    }
}
