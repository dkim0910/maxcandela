import Foundation
import RevenueCat
import StoreKit

/// Trial → paid conversion tracking via RevenueCat, in its "purchases are
/// completed by my app" mode.
///
/// `StoreManager` stays the only thing that talks to StoreKit: it loads
/// products, runs the payment sheet, verifies and finishes transactions.
/// RevenueCat is a ledger. It learns that this install exists (`configure()`
/// at launch — the customer is "first seen" that day) and which installs go
/// on to buy (`record` after a successful StoreKit purchase). Those two facts
/// are what its New Customers and Conversion to Paying charts plot.
///
/// What this deliberately is NOT:
///  - the source of truth for the licence. `StoreManager.currentState()`
///    still decides from `Transaction.currentEntitlements`; RevenueCat being
///    unreachable, unconfigured or wrong can never gate the boost.
///  - a second identifier. The app user ID is the same random per-install
///    UUID GA already uses (`Analytics.clientID`), so the privacy posture is
///    unchanged: one anonymous ID, reset by deleting the app's preferences.
///  - a row on RevenueCat's "Trials" chart. That chart counts App Store
///    introductory free trials on subscriptions; the 5-day trial here is an
///    app-side clock the store knows nothing about. Trial state is exposed
///    instead as the `license_state` subscriber attribute (trial / expired /
///    licensed) so customer lists can be filtered by it.
///
/// Credentials: the *public* SDK key (`appl_…`, designed to ship in the
/// binary) is read from Info.plist `RCPublicAPIKey`, which both bundlers fill
/// from `RC_PUBLIC_API_KEY` in the repo-root `.env`. Empty key ⇒ silently
/// off, same as `Analytics`. DEBUG builds are off unless `MAXCANDELA_RC_API_KEY`
/// is set in the environment — a bare `swift run` has no Info.plist, and dev
/// launches must not register as customers.
///
/// RevenueCat only accepts StoreKit 2 transactions once the App Store
/// Connect In-App Purchase Key (.p8) is uploaded to the RevenueCat app
/// (console-side; see CLAUDE.md). Until then installs count, purchases don't.
///
/// App Store privacy label implication (App Store Connect → App Privacy):
/// adds "Purchases → Purchase History" and "Identifiers → User ID", both not
/// linked to identity, used for Analytics. `/privacy` on the site discloses it.
enum ConversionTracker {
    private static var isConfigured = false

    /// Subscriber-attribute keys. Stable names — the RevenueCat dashboard
    /// filters on them, so renaming one silently empties a saved filter.
    enum AttributeKey {
        static let licenseState = "license_state"
        static let trialDaysLeft = "trial_days_left"
    }

    private static var apiKey: String? {
        #if DEBUG
        let key = ProcessInfo.processInfo.environment["MAXCANDELA_RC_API_KEY"] ?? ""
        #else
        let key = Bundle.main.object(forInfoDictionaryKey: "RCPublicAPIKey") as? String ?? ""
        #endif
        return key.isEmpty ? nil : key
    }

    /// Configure once, early in launch, before any purchase can happen.
    static func configure() {
        guard !isConfigured, let apiKey else { return }
        isConfigured = true
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(
            with: Configuration.builder(withAPIKey: apiKey)
                .with(appUserID: Analytics.clientID)
                .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
        )
    }

    /// Hand a successful StoreKit 2 purchase to RevenueCat. Purchases made
    /// through `Product.purchase()` never appear on `Transaction.updates` in
    /// the same process, so without this call RevenueCat would only ever see
    /// renewals. Fire-and-forget: it must never delay or fail the purchase
    /// the user just made.
    static func record(_ result: Product.PurchaseResult) {
        guard isConfigured else { return }
        Task.detached(priority: .utility) {
            do {
                _ = try await Purchases.shared.recordPurchase(result)
            } catch {
                NSLog("MaxCandela: RevenueCat could not record purchase: \(error.localizedDescription)")
            }
        }
    }

    /// After Restore Purchases: re-post the receipt so a purchase made on
    /// another Mac lands on this customer instead of looking like a churned
    /// trial. Best effort.
    static func syncPurchases() {
        guard isConfigured else { return }
        Task.detached(priority: .utility) {
            do {
                _ = try await Purchases.shared.syncPurchases()
            } catch {
                NSLog("MaxCandela: RevenueCat sync failed: \(error.localizedDescription)")
            }
        }
    }

    /// Mirror the resolved licence state onto the customer. Cheap to call on
    /// every refresh — the SDK caches attributes and only uploads changes.
    ///
    /// The explicit sync matters: the SDK normally uploads attributes when
    /// the app resigns active or on the next launch, and an accessory app
    /// never resigns active — verified 2026-09-03: without it the customer
    /// appeared in the dashboard with no `license_state` at all. Rate-limited
    /// by the SDK to 5/min, which the 30-min licence refresh never reaches.
    static func update(licenseState: StoreManager.LicenseState) {
        guard isConfigured else { return }
        Purchases.shared.attribution.setAttributes(attributes(for: licenseState))
        Task.detached(priority: .utility) {
            _ = try? await Purchases.shared.syncAttributesAndOfferingsIfNeeded()
        }
    }

    /// Pure mapping from licence state to subscriber attributes (unit-tested).
    /// An empty value clears the attribute on RevenueCat's side.
    static func attributes(for state: StoreManager.LicenseState) -> [String: String] {
        switch state {
        case .licensed:
            return [AttributeKey.licenseState: "licensed", AttributeKey.trialDaysLeft: ""]
        case .trial(let daysRemaining):
            return [AttributeKey.licenseState: "trial", AttributeKey.trialDaysLeft: String(daysRemaining)]
        case .expired:
            return [AttributeKey.licenseState: "expired", AttributeKey.trialDaysLeft: "0"]
        }
    }
}
