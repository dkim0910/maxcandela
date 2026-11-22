import AppKit

/// One tool in the menu-bar toolbox. Each tool owns a single top-level menu
/// item (normally with a submenu) and nothing else — MenuBarController only
/// places the items and forwards these calls, so adding a tool is one new file
/// plus one line in `MenuBarController.makeTools()`.
///
/// Rules every tool follows:
///  - public API only, and nothing the App Store sandbox needs a new
///    entitlement for (say so in the type comment if that ever changes);
///  - no persistent *system* state: quitting the app undoes everything;
///  - the logic that can be pure is, and is unit-tested.
protocol MenuTool: AnyObject {
    var menuItem: NSMenuItem { get }

    /// The menu is about to open: rebuild anything that may have changed.
    func menuWillOpen()

    /// Called a few times a second while the menu is open, for live figures.
    func tick()

    /// Short text to show next to the status icon (a running countdown), or
    /// nil. Call `onStatusChange` when it changes.
    var statusText: String? { get }
    var onStatusChange: (() -> Void)? { get set }

    /// The app is quitting: release anything held.
    func shutdown()

    /// The whole tool is part of MaxCandela Pro. MenuBarController then shows
    /// a "— Pro" row that opens the paywall in its place while Pro is not
    /// available. A tool that is only *partly* Pro (Clipboard) leaves this
    /// false and consults `ProGate` itself.
    var isPro: Bool { get }

    /// False when this macOS lacks the API the tool is built on; the tool is
    /// then left out of the menu entirely (`MenuBarController.tools`).
    var isSupported: Bool { get }
}

extension MenuTool {
    func menuWillOpen() {}
    func tick() {}
    var statusText: String? { nil }
    func shutdown() {}
    var isPro: Bool { false }
    var isSupported: Bool { true }
}

/// Whether this process runs in the App Sandbox — true for the Mac App Store
/// build, false under `swift run`. Tools whose API the sandbox blocks hide
/// themselves on it (`isSupported`) rather than appear and silently fail.
enum AppSandbox {
    static var isActive: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }
}
