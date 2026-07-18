import AppKit

/// The menu-bar surface. Left-clicking the ☀️ status icon toggles the boost
/// instantly; right-clicking opens a menu with the boost slider, headroom info,
/// and Quit. Talks only to BrightnessController.
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let brightness: BrightnessController
    private let slider: NSSlider
    private let headroomItem: NSMenuItem
    private let menu: NSMenu

    init(brightness: BrightnessController) {
        self.brightness = brightness
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        self.slider = NSSlider(value: Double(brightness.requestedBoost),
                               minValue: 1.0,
                               maxValue: Double(max(1.01, brightness.maxPotentialBoost())),
                               target: nil,
                               action: nil)
        self.headroomItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        self.menu = NSMenu()

        configureStatusButton()
        buildMenu()
        refresh()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusButtonClicked)
        // Receive both left and right clicks so we can toggle vs. show menu.
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func buildMenu() {
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
    }

    /// Sync the icon with the enabled state so the button reads as a toggle.
    private func refresh() {
        if let button = statusItem.button {
            let symbol = brightness.isEnabled ? "sun.max.fill" : "sun.min"
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "MaxCandela")
            button.image?.isTemplate = true
        }
        let potential = brightness.maxPotentialBoost()
        if let live = brightness.liveStatus() {
            headroomItem.title = String(format: "Boosting %.2f× (headroom %.2f×)",
                                        live.applied, live.headroom)
        } else if potential > 1.0 {
            headroomItem.title = String(format: "Headroom: up to %.1f×", potential)
        } else {
            headroomItem.title = "No EDR headroom on this display"
        }
    }

    // MARK: - Actions

    @objc private func statusButtonClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            brightness.toggle()
            refresh()
        }
    }

    private func showMenu() {
        refresh()
        // Assign the menu just long enough to pop it up, then detach so plain
        // left-clicks keep reaching statusButtonClicked (an attached menu
        // hijacks all clicks on the status item).
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func sliderChanged() {
        brightness.setBoost(CGFloat(slider.doubleValue))
    }
}
