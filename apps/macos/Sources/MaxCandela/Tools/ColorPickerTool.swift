import AppKit

/// Pick a Color: the system eyedropper (`NSColorSampler` — public, and it
/// needs no Screen Recording permission because the system draws the loupe),
/// with the picked colour copied as hex and the last few kept in the menu.
final class ColorPickerTool: MenuTool {
    let menuItem = NSMenuItem(title: "Color Picker", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?

    private let submenu = NSMenu()
    /// Held for the duration of a pick; the sampler is released otherwise.
    private var sampler: NSColorSampler?

    private static let recentsKey = "com.maxcandela.colors.recent"
    private static let recentsLimit = 8

    private var recents: [String] {
        get { UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Self.recentsKey) }
    }

    init() {
        menuItem.submenu = submenu
        menuItem.symbol("eyedropper")
        rebuild()
    }

    func menuWillOpen() { rebuild() }

    /// Pure, unit-tested. sRGB components 0…1 → "#RRGGBB".
    static func hex(red: Double, green: Double, blue: Double) -> String {
        func byte(_ value: Double) -> Int { Int((max(0, min(1, value)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    /// Pure, unit-tested. "#RRGGBB" → components, or nil if it isn't one.
    static func components(hex: String) -> (red: Double, green: Double, blue: Double)? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
    }

    /// Pure, unit-tested. Newest first, no duplicates, capped.
    static func adding(_ hex: String, to recents: [String], limit: Int = recentsLimit) -> [String] {
        Array(([hex] + recents.filter { $0 != hex }).prefix(limit))
    }

    private func rebuild() {
        submenu.removeAllItems()
        let pick = NSMenuItem(title: "Pick a Color from the Screen…", action: #selector(pick), keyEquivalent: "")
        pick.target = self
        submenu.addItem(pick)

        let colors = recents
        guard !colors.isEmpty else { return }
        submenu.addItem(.separator())
        let header = NSMenuItem(title: "Recent — click to copy", action: nil, keyEquivalent: "")
        header.isEnabled = false
        submenu.addItem(header)
        for hex in colors {
            let item = NSMenuItem(title: hex, action: #selector(copyRecent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = hex
            item.image = Self.swatch(hex)
            submenu.addItem(item)
        }
    }

    private static func swatch(_ hex: String) -> NSImage? {
        guard let c = components(hex: hex) else { return nil }
        let size = NSSize(width: 14, height: 14)
        return NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
            NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1).setFill()
            path.fill()
            NSColor.separatorColor.setStroke()
            path.stroke()
            return true
        }
    }

    @objc private func pick() {
        let sampler = NSColorSampler()
        self.sampler = sampler
        sampler.show { [weak self] color in
            self?.sampler = nil
            // nil == the user pressed Escape.
            guard let self, let rgb = color?.usingColorSpace(.sRGB) else { return }
            let hex = Self.hex(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
            self.recents = Self.adding(hex, to: self.recents)
            self.copy(hex)
        }
    }

    @objc private func copyRecent(_ sender: NSMenuItem) {
        guard let hex = sender.representedObject as? String else { return }
        copy(hex)
    }

    private func copy(_ hex: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hex, forType: .string)
    }
}
