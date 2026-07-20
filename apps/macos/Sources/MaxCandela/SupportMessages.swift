import Foundation

/// User-facing copy that explains which Macs MaxCandela can actually boost.
///
/// Lives here rather than inline in `MenuBarController` so it can be unit
/// tested. App Review rejected 1.0.4 (2026-07-20) after testing on a MacBook
/// Air M3 — a machine with no EDR headroom, where the boost cannot engage.
/// The wording below is deliberately model-specific: "M1 or newer" is *wrong*
/// (an M1 MacBook Air is M1 and never boosts), so every message names the
/// MacBook Pro 14"/16" and the Pro Display XDR, and calls out the Macs that
/// are not supported.
enum SupportMessages {
    /// Machines whose built-in or attached display has HDR/EDR headroom.
    static let supportedHardware =
        "MacBook Pro 14″ or 16″ with an M1 Pro / M1 Max chip or newer (2021 and later), or a Pro Display XDR"

    /// Title of the alert shown when the user asks to boost a display that
    /// has no headroom to give.
    static let noHeadroomTitle = "No brightness boost available"

    /// Body of that alert. Leads with reassurance (nothing is broken), then
    /// the supported list, then the common Macs that are not supported —
    /// including newer Apple silicon, which is the case that confuses people.
    static let noHeadroomBody = """
    This display doesn’t have the HDR (EDR) headroom MaxCandela needs, so there’s nothing to unlock. Nothing is wrong with your Mac — this display simply has no reserve brightness to release.

    MaxCandela needs the built-in screen of a \(supportedHardware).

    MacBook Air, iMac, Mac mini with a standard monitor, and most external displays don’t have this headroom — including newer Apple silicon models.
    """

    /// Compact form for the status-item menu, where space is tight.
    static let noHeadroomMenuLine = "No HDR headroom — needs a MacBook Pro XDR display"
}
