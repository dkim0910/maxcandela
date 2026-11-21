import Foundation
import StoreKit

/// Asks for an App Store rating — once per app version, and only of someone
/// who has plainly got value out of the app.
///
/// The bar is deliberately high, because a prompt shown to the wrong person
/// earns a one-star review rather than nothing:
///  - a paying customer (not a trial — they have not decided yet);
///  - who has switched the boost on at least `minimumBoosts` times;
///  - over at least `minimumDays` days;
///  - never on hardware where macOS is reported to break the boost.
/// Apple additionally caps the system prompt at three showings a year and
/// may show nothing at all; this code cannot tell which.
enum ReviewPrompt {
    static let minimumBoosts = 10
    static let minimumDays = 7

    private enum Key {
        static let count = "com.maxcandela.review.boostCount"
        static let first = "com.maxcandela.review.firstBoostAt"
        static let askedVersion = "com.maxcandela.review.askedVersion"
    }

    /// Pure, unit-tested.
    static func shouldAsk(isPaying: Bool, boostCount: Int, firstBoost: Date?,
                          lastAskedVersion: String?, currentVersion: String,
                          boostReportedBroken: Bool, now: Date = Date()) -> Bool {
        guard isPaying, !boostReportedBroken, boostCount >= minimumBoosts,
              lastAskedVersion != currentVersion, let firstBoost
        else { return false }
        return now.timeIntervalSince(firstBoost) >= Double(minimumDays) * 86_400
    }

    /// Call each time the user switches the boost on. Counts it and, when the
    /// bar is met, asks a few seconds later — not on top of the click.
    static func boostWasSwitchedOn(isPaying: Bool, defaults: UserDefaults = .standard) {
        defaults.set(defaults.integer(forKey: Key.count) + 1, forKey: Key.count)
        if defaults.object(forKey: Key.first) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: Key.first)
        }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let first = Date(timeIntervalSince1970: defaults.double(forKey: Key.first))
        guard shouldAsk(isPaying: isPaying,
                        boostCount: defaults.integer(forKey: Key.count),
                        firstBoost: first,
                        lastAskedVersion: defaults.string(forKey: Key.askedVersion),
                        currentVersion: version,
                        boostReportedBroken: KnownIssues.gammaLiftReportedBroken)
        else { return }
        defaults.set(version, forKey: Key.askedVersion)
        #if DEBUG
        // The dev auto-unlock reports "licensed", and a dev run has no store
        // listing to rate.
        NSLog("MaxCandela: would ask for an App Store rating now (skipped in DEBUG)")
        #else
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            SKStoreReviewController.requestReview()
        }
        #endif
    }
}
