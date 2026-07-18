import Foundation
import StoreKit

/// Licensing: free download, 5-day full trial, then either a monthly
/// subscription or a lifetime unlock via Apple in-app purchase.
///
/// Product IDs must match App Store Connect exactly:
///   com.maxcandela.pro.lifetime — non-consumable, $9.99
///   com.maxcandela.pro.monthly  — auto-renewable subscription, $0.99/month
///
/// Trial note (v1): the trial clock is the first-launch date in UserDefaults.
/// That's resettable by a determined user; the robust upgrade is the app
/// receipt's original purchase date — tracked in CLAUDE.md TODO.
final class StoreManager {
    enum LicenseState: Equatable {
        case licensed
        case trial(daysRemaining: Int)
        case expired
    }

    static let shared = StoreManager()

    static let lifetimeProductID = "com.maxcandela.pro.lifetime"
    static let monthlyProductID = "com.maxcandela.pro.monthly"
    private static let productIDs: Set<String> = [lifetimeProductID, monthlyProductID]

    private static let trialDays = 5
    private static let firstLaunchKey = "com.maxcandela.firstLaunchDate"

    private let defaults: UserDefaults
    private(set) var products: [Product] = []
    private var transactionListener: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.firstLaunchKey) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: Self.firstLaunchKey)
        }
    }

    // MARK: - Trial clock (pure logic split out for tests)

    static func trialDaysRemaining(firstLaunch: Date, now: Date = Date(), length: Int = trialDays) -> Int {
        let elapsed = now.timeIntervalSince(firstLaunch)
        guard elapsed >= 0 else { return length }  // clock rolled back: be lenient
        let daysUsed = Int(elapsed / 86_400)
        return max(0, length - daysUsed)
    }

    var trialDaysRemaining: Int {
        let stamp = defaults.double(forKey: Self.firstLaunchKey)
        return Self.trialDaysRemaining(firstLaunch: Date(timeIntervalSince1970: stamp))
    }

    // MARK: - License state

    /// The current license state: a verified, unrevoked App Store entitlement
    /// wins; otherwise the trial clock decides.
    func currentState() async -> LicenseState {
        #if DEBUG
        // Force a license state for testing:
        //   MAXCANDELA_FORCE_TRIAL=expired|trial|licensed
        // (real StoreKit entitlements can't be exercised outside the App Store).
        if let forced = ProcessInfo.processInfo.environment["MAXCANDELA_FORCE_TRIAL"] {
            switch forced {
            case "licensed": return .licensed
            case "expired": return .expired
            case "trial": return .trial(daysRemaining: Self.trialDays)
            default:
                // A number forces that many days remaining (0 = expired).
                if let days = Int(forced) {
                    return days > 0 ? .trial(daysRemaining: days) : .expired
                }
            }
        }
        // Otherwise debug builds stay unlocked so development isn't gated on
        // App Store Connect. Set MAXCANDELA_FORCE_PAYWALL=1 to reach the real
        // entitlement/trial-clock path below.
        if ProcessInfo.processInfo.environment["MAXCANDELA_FORCE_PAYWALL"] == nil {
            return .licensed
        }
        #endif

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                return .licensed
            }
        }

        let remaining = trialDaysRemaining
        return remaining > 0 ? .trial(daysRemaining: remaining) : .expired
    }

    // MARK: - Store operations

    /// Load products from the App Store. Harmless to call repeatedly; no-ops
    /// outside an App Store environment (dev builds without a receipt).
    func loadProducts() async {
        guard products.isEmpty else { return }
        do {
            products = try await Product.products(for: Self.productIDs)
        } catch {
            NSLog("MaxCandela: could not load App Store products: \(error.localizedDescription)")
        }
    }

    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

    /// Purchase a product. Returns true if the user now holds the entitlement.
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                return true
            }
            return false
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// Ask the App Store to sync entitlements (the "Restore Purchases" path).
    func restorePurchases() async {
        try? await AppStore.sync()
    }

    /// Keep entitlements current while the app runs (renewals, refunds,
    /// purchases made on another Mac).
    func startTransactionListener(onChange: @escaping () -> Void) {
        transactionListener?.cancel()
        transactionListener = Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await MainActor.run { onChange() }
                }
            }
        }
    }
}
