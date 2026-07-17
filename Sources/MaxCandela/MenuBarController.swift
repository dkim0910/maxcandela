import AppKit

/// The menu-bar surface: a status item with an enable toggle, a boost slider,
/// and per-launch info about available headroom. Talks only to
/// BrightnessController.
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let brightness: BrightnessController
    private let slider: NSSlider
    private let enableItem: NSMenuItem
    private let headroomItem: NSMenuItem

    init(brightness: BrightnessController) {
        self.brightness = brightness
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        self.slider = NSSlider(value: Double(brightness.requestedBoost),
                               minValue: 1.0,
                               maxValue: Double(max(1.01, brightness.maxPotentialBoost())),
                               target: nil,
                               action: nil)
        self.enableItem = NSMenuItem(title: "Enabled", action: nil, keyEquivalent: "")
        self.headroomItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

        configureStatusButton()
        buildMenu()
        refresh()
    }

    private func configureStatusButton() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "MaxCandela")
            button.image?.isTemplate = true
        }
    }

    private func buildMenu() {
        let menu = NSMenu()

        enableItem.target = self
        enableItem.action = #selector(toggleEnabled)
        menu.addItem(enableItem)

        menu.addItem(.separator())

        // Boost slider embedded in a menu item via a custom view.
        let boostLabel = NSMenuItem(title: "Boost", action: nil, keyEquivalent: "")
        boostLabel.isEnabled = false
        menu.addItem(boostLabel)

        slider.target = self
        slider.action = #selector(sliderChanged)
        let sliderItem = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 28))
        slider.frame = NSRect(x: 14, y: 4, width: 172, height: 20)
        container.addSubview(slider)
        sliderItem.view = container
        menu.addItem(sliderItem)

        headroomItem.isEnabled = false
        menu.addItem(headroomItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit MaxCandela",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func refresh() {
        enableItem.state = brightness.isEnabled ? .on : .off
        let potential = brightness.maxPotentialBoost()
        if potential > 1.0 {
            headroomItem.title = String(format: "Headroom: up to %.1f×", potential)
        } else {
            headroomItem.title = "No EDR headroom on this display"
        }
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        brightness.toggle()
        refresh()
    }

    @objc private func sliderChanged() {
        brightness.setBoost(CGFloat(slider.doubleValue))
    }
}
