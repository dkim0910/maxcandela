import AppKit

/// A labelled slider that lives inside an NSMenuItem (`item.view`). Used for
/// Extra Dim and Warmth, which need a continuous value the user can watch
/// change on the glass while dragging — a submenu of presets can't do that.
///
/// Laid out like a menu row with a control under it: icon and title on the
/// left where every other row has them, the current value on the right in
/// secondary colour, and the slider spanning the width beneath.
///
/// A slider inside a menu tracks normally: the menu's event-tracking run loop
/// delivers the drag to the view, and `isContinuous` reports every step.
final class SliderMenuItemView: NSView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let valueLabel = NSTextField(labelWithString: "")
    private let slider = NSSlider()
    private let onChange: (Double) -> Void
    private let describe: (Double) -> String

    /// `value` and the callback are both 0…1. `describe` turns a value into
    /// the text shown on the right ("Off", "40%").
    init(title: String, symbol: String, value: Double,
         describe: @escaping (Double) -> String = SliderMenuItemView.percent,
         onChange: @escaping (Double) -> Void) {
        self.onChange = onChange
        self.describe = describe
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 46))
        autoresizingMask = [.width]

        // Where AppKit puts a row's icon and title in a menu whose rows have
        // icons (measured against the neighbouring rows on macOS 26).
        let inset: CGFloat = 14
        let iconSize: CGFloat = 16
        let textX = inset + iconSize + 6

        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.contentTintColor = .labelColor
        icon.frame = NSRect(x: inset, y: 24, width: iconSize, height: iconSize)
        addSubview(icon)

        label.stringValue = title
        label.font = NSFont.menuFont(ofSize: 0)
        label.textColor = .labelColor
        label.frame = NSRect(x: textX, y: 23, width: 140, height: 18)
        addSubview(label)

        valueLabel.alignment = .right
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.frame = NSRect(x: bounds.width - inset - 70, y: 23, width: 70, height: 18)
        valueLabel.autoresizingMask = [.minXMargin]
        addSubview(valueLabel)

        slider.minValue = 0
        slider.maxValue = 1
        slider.doubleValue = value
        slider.isContinuous = true
        slider.controlSize = .small
        slider.target = self
        slider.action = #selector(sliderMoved)
        slider.frame = NSRect(x: textX, y: 4, width: bounds.width - textX - inset, height: 18)
        slider.autoresizingMask = [.width]
        slider.setAccessibilityLabel(title)
        addSubview(slider)

        valueLabel.stringValue = describe(value)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Pure, unit-tested. The slider's leftmost stretch reads "Off" — where
    /// the adjustment is too slight to see is not worth a number.
    static func percent(_ value: Double) -> String {
        let percent = Int((max(0, min(1, value)) * 100).rounded())
        return percent < 1 ? "Off" : "\(percent)%"
    }

    var isEnabled: Bool {
        get { slider.isEnabled }
        set {
            guard newValue != slider.isEnabled else { return }
            slider.isEnabled = newValue
            label.textColor = newValue ? .labelColor : .tertiaryLabelColor
            icon.contentTintColor = newValue ? .labelColor : .tertiaryLabelColor
            valueLabel.isHidden = !newValue
        }
    }

    @objc private func sliderMoved() {
        valueLabel.stringValue = describe(slider.doubleValue)
        onChange(slider.doubleValue)
    }
}
