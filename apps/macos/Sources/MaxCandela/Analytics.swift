import Foundation

/// Lightweight GA4 analytics via the Measurement Protocol — no SDK, one HTTPS
/// call per event, fire-and-forget.
///
/// Privacy posture (mirrored on the website's privacy page — keep in sync):
///  - a random per-install UUID is the only identifier; it is not tied to the
///    user's name, email, Apple ID, or hardware
///  - events carry no content, no screen data, no personal fields
///  - nothing is sent from DEBUG builds
///  - silently disabled until real credentials are configured below
///
/// App Store privacy label implication: "Usage Data — Analytics, not linked
/// to identity" (no longer "Data Not Collected").
enum Analytics {
    // TODO: fill from Google Analytics admin — create a GA4 property, then
    // Admin → Data Streams → (stream) → Measurement Protocol API secrets.
    private static let measurementID = "G-XXXXXXXXXX"
    private static let apiSecret = "REPLACE_ME"

    private static let clientIDKey = "com.maxcandela.analyticsClientID"

    private static var isConfigured: Bool {
        !measurementID.contains("XXXX") && apiSecret != "REPLACE_ME"
    }

    /// Random per-install identifier; created lazily, never leaves this Mac
    /// except inside analytics events.
    private static var clientID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: clientIDKey) {
            return existing
        }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: clientIDKey)
        return fresh
    }

    /// Send one event. Never throws, never blocks, never retries — analytics
    /// must not affect the app.
    static func track(_ name: String, params: [String: Any] = [:]) {
        #if DEBUG
        NSLog("MaxCandela: analytics (debug, not sent): %@ %@", name, String(describing: params))
        #else
        guard isConfigured else { return }
        var components = URLComponents(string: "https://www.google-analytics.com/mp/collect")!
        components.queryItems = [
            URLQueryItem(name: "measurement_id", value: measurementID),
            URLQueryItem(name: "api_secret", value: apiSecret),
        ]
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "client_id": clientID,
            "events": [["name": name, "params": params]],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = data
        URLSession.shared.dataTask(with: request).resume()
        #endif
    }
}
