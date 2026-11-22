import AppKit

/// One app's row in App Volume, laid out like `SliderMenuItemView`: the
/// app's icon and name where a menu row has them, its level on the right in
/// secondary colour with a mute button after it, and a 0–200% slider across
/// the width beneath.
final class AppVolumeRowView: NSView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")
    private let muteButton = NSButton()
    private let slider = NSSlider()
    private let appName: String
    private var percent: Double
    private var muted: Bool
    private let onPercent: (Double) -> Void
    private let onMute: (Bool) -> Void

    init(name: String, image: NSImage?, percent: Double, muted: Bool,
         onPercent: @escaping (Double) -> Void, onMute: @escaping (Bool) -> Void) {
        self.appName = name
        self.percent = AppVolumeMath.snapped(percent)
        self.muted = muted
        self.onPercent = onPercent
        self.onMute = onMute
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 46))
        autoresizingMask = [.width]

        // Same measurements as SliderMenuItemView.
        let inset: CGFloat = 14
        let iconSize: CGFloat = 16
        let textX = inset + iconSize + 6
        let buttonSize: CGFloat = 18

        icon.image = image ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.frame = NSRect(x: inset, y: 24, width: iconSize, height: iconSize)
        addSubview(icon)

        label.stringValue = name
        label.font = NSFont.menuFont(ofSize: 0)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: textX, y: 23, width: bounds.width - textX - inset - buttonSize - 70, height: 18)
        label.autoresizingMask = [.width]
        addSubview(label)

        valueLabel.alignment = .right
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.frame = NSRect(x: bounds.width - inset - buttonSize - 4 - 60, y: 23, width: 60, height: 18)
        valueLabel.autoresizingMask = [.minXMargin]
        addSubview(valueLabel)

        muteButton.isBordered = false
        muteButton.imagePosition = .imageOnly
        muteButton.target = self
        muteButton.action = #selector(muteClicked)
        muteButton.frame = NSRect(x: bounds.width - inset - buttonSize, y: 23, width: buttonSize, height: buttonSize)
        muteButton.autoresizingMask = [.minXMargin]
        addSubview(muteButton)

        slider.minValue = 0
        slider.maxValue = AppVolumeMath.maxPercent
        slider.doubleValue = self.percent
        slider.isContinuous = true
        slider.controlSize = .small
        slider.target = self
        slider.action = #selector(sliderMoved)
        slider.frame = NSRect(x: textX, y: 4, width: bounds.width - textX - inset, height: 18)
        slider.autoresizingMask = [.width]
        slider.setAccessibilityLabel("\(name) volume")
        addSubview(slider)

        update()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func update() {
        valueLabel.stringValue = AppVolumeMath.describe(percent: percent, muted: muted)
        let symbol = muted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        let description = muted ? "Unmute \(appName)" : "Mute \(appName)"
        muteButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        muteButton.contentTintColor = muted ? .systemRed : .secondaryLabelColor
        muteButton.toolTip = description
    }

    @objc private func sliderMoved() {
        let snapped = AppVolumeMath.snapped(slider.doubleValue)
        // Holding the knob on 100% while the pointer is near it is what
        // makes "no change at all" easy to find.
        if snapped != slider.doubleValue { slider.doubleValue = snapped }
        // Moving the slider means "I want to hear it", like the volume keys.
        if muted {
            muted = false
            onMute(false)
        }
        guard snapped != percent else { update(); return }
        percent = snapped
        update()
        onPercent(snapped)
    }

    @objc private func muteClicked() {
        muted.toggle()
        update()
        onMute(muted)
    }
}
