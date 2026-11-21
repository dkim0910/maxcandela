import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Where a window can be sent. Pure geometry, unit-tested.
enum SnapRegion: CaseIterable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case maximize, center

    var title: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .maximize: return "Maximize"
        case .center: return "Center"
        }
    }

    var symbol: String {
        switch self {
        case .leftHalf: return "rectangle.lefthalf.filled"
        case .rightHalf: return "rectangle.righthalf.filled"
        case .topHalf: return "rectangle.tophalf.filled"
        case .bottomHalf: return "rectangle.bottomhalf.filled"
        case .topLeft: return "rectangle.inset.topleft.filled"
        case .topRight: return "rectangle.inset.topright.filled"
        case .bottomLeft: return "rectangle.inset.bottomleft.filled"
        case .bottomRight: return "rectangle.inset.bottomright.filled"
        case .maximize: return "rectangle.fill"
        case .center: return "rectangle.center.inset.filled"
        }
    }

    /// ⌃⌥ + this key, the convention window managers on the Mac share.
    var hotKey: (keyCode: Int, glyph: String)? {
        switch self {
        case .leftHalf: return (kVK_LeftArrow, "←")
        case .rightHalf: return (kVK_RightArrow, "→")
        case .topHalf: return (kVK_UpArrow, "↑")
        case .bottomHalf: return (kVK_DownArrow, "↓")
        case .maximize: return (kVK_Return, "↩")
        case .center: return (kVK_ANSI_C, "C")
        default: return nil
        }
    }

    /// The target frame inside a screen's usable area, in AppKit coordinates
    /// (origin bottom-left). `current` matters only for `.center`, which
    /// keeps the window's size.
    func frame(in visible: CGRect, current: CGSize = .zero) -> CGRect {
        let halfW = visible.width / 2, halfH = visible.height / 2
        switch self {
        case .leftHalf: return CGRect(x: visible.minX, y: visible.minY, width: halfW, height: visible.height)
        case .rightHalf: return CGRect(x: visible.midX, y: visible.minY, width: halfW, height: visible.height)
        case .topHalf: return CGRect(x: visible.minX, y: visible.midY, width: visible.width, height: halfH)
        case .bottomHalf: return CGRect(x: visible.minX, y: visible.minY, width: visible.width, height: halfH)
        case .topLeft: return CGRect(x: visible.minX, y: visible.midY, width: halfW, height: halfH)
        case .topRight: return CGRect(x: visible.midX, y: visible.midY, width: halfW, height: halfH)
        case .bottomLeft: return CGRect(x: visible.minX, y: visible.minY, width: halfW, height: halfH)
        case .bottomRight: return CGRect(x: visible.midX, y: visible.minY, width: halfW, height: halfH)
        case .maximize: return visible
        case .center:
            let size = CGSize(width: min(current.width, visible.width), height: min(current.height, visible.height))
            return CGRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                          width: size.width, height: size.height)
        }
    }

    /// AppKit puts the origin at the bottom-left of the primary screen with y
    /// going up; the Accessibility API puts it at the top-left with y going
    /// down. This is the window's top-left corner in the latter.
    static func accessibilityOrigin(of frame: CGRect, primaryScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: frame.minX, y: primaryScreenHeight - frame.maxY)
    }
}

/// Window Snapping (Pro): send the front window to a half, a quarter, the
/// whole screen or the centre — from the menu, or with ⌃⌥ shortcuts.
///
/// Moving another app's window is only possible through the Accessibility
/// API, so this is the one tool that asks for a system permission (System
/// Settings ▸ Privacy & Security ▸ Accessibility). It is requested the first
/// time the user snaps a window, never at launch. No entitlement is involved.
///
/// ⚠️ Not exercised at runtime during development: the dev binary has no
/// Accessibility grant. The geometry is unit-tested; the AX calls are not.
final class WindowSnapTool: MenuTool {
    let menuItem = NSMenuItem(title: "Window Snapping", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?
    var isPro: Bool { true }

    private let shortcutsItem = NSMenuItem(title: "Use ⌃⌥ Shortcuts", action: nil, keyEquivalent: "")
    private var hotKeys: [GlobalHotKey] = []
    private static let shortcutsKey = "com.maxcandela.snap.shortcuts"

    private var shortcutsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.shortcutsKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.shortcutsKey) }
    }

    init() {
        let submenu = NSMenu()
        for (index, region) in SnapRegion.allCases.enumerated() {
            if region == .topLeft || region == .maximize { submenu.addItem(.separator()) }
            let title = region.hotKey.map { "\(region.title)   ⌃⌥\($0.glyph)" } ?? region.title
            let item = NSMenuItem(title: title, action: #selector(snap(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            submenu.addItem(item.symbol(region.symbol))
        }
        submenu.addItem(.separator())
        shortcutsItem.target = self
        shortcutsItem.action = #selector(toggleShortcuts)
        submenu.addItem(shortcutsItem.symbol("keyboard"))
        menuItem.submenu = submenu
        menuItem.symbol("rectangle.split.2x1")

        ProGate.shared.observe { [weak self] allowed in
            if allowed { self?.registerIfWanted() } else { self?.unregister() }
        }
        if ProGate.shared.isAllowed { registerIfWanted() }
        updateMenu()
    }

    func menuWillOpen() { updateMenu() }
    func shutdown() { unregister() }

    private func updateMenu() {
        shortcutsItem.state = hotKeys.isEmpty ? .off : .on
    }

    @objc private func snap(_ sender: NSMenuItem) {
        perform(SnapRegion.allCases[sender.tag])
    }

    @objc private func toggleShortcuts() {
        shortcutsEnabled.toggle()
        if shortcutsEnabled { registerIfWanted() } else { unregister() }
        updateMenu()
    }

    private func registerIfWanted() {
        guard shortcutsEnabled, hotKeys.isEmpty else { return }
        for region in SnapRegion.allCases {
            guard let key = region.hotKey else { continue }
            let hotKey = GlobalHotKey()
            hotKey.onPress = { [weak self] in self?.perform(region) }
            let shortcut = Shortcut(keyCode: UInt32(key.keyCode),
                                    carbonModifiers: UInt32(controlKey | optionKey),
                                    display: "⌃⌥\(key.glyph)")
            // A chord another app already owns is skipped; the rest still work.
            if hotKey.register(shortcut) { hotKeys.append(hotKey) }
        }
    }

    private func unregister() {
        hotKeys.forEach { $0.unregister() }
        hotKeys.removeAll()
    }

    private func perform(_ region: SnapRegion) {
        // Asks once, with the system's own dialog pointing at the right pane.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { return }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }

        let element = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            NSSound.beep()
            return
        }
        let window = focused as! AXUIElement
        guard let primary = NSScreen.screens.first else { return }

        // Find the screen the window is mostly on, via its current AX frame.
        var position = CGPoint.zero, size = CGSize.zero
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value) == .success, let value {
            AXValueGetValue(value as! AXValue, .cgPoint, &position)
        }
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value) == .success, let value {
            AXValueGetValue(value as! AXValue, .cgSize, &size)
        }
        let centre = CGPoint(x: position.x + size.width / 2,
                             y: primary.frame.height - (position.y + size.height / 2))
        let screen = NSScreen.screens.first { $0.frame.contains(centre) } ?? NSScreen.main ?? primary

        let target = region.frame(in: screen.visibleFrame, current: size)
        var origin = SnapRegion.accessibilityOrigin(of: target, primaryScreenHeight: primary.frame.height)
        var newSize = target.size
        guard let originValue = AXValueCreate(.cgPoint, &origin),
              let sizeValue = AXValueCreate(.cgSize, &newSize) else { return }
        // Size, position, size again: a window that was too big for the new
        // spot is clamped on the first resize, and one moving between screens
        // only accepts the full size once it has arrived.
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, originValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    }
}
