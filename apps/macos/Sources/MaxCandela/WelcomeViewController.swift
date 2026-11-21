import AppKit

/// The first-run callout shown in a popover anchored to the menu-bar ☀️ icon.
/// Its whole job is to tell the user "the app lives up here" — menu-bar apps
/// have no window or Dock icon, so first-timers otherwise can't find them.
final class WelcomeViewController: NSViewController {
    private let onDismiss: () -> Void
    private let icon: NSImage?
    private let clickTogglesBoost: Bool

    init(icon: NSImage?, clickTogglesBoost: Bool, onDismiss: @escaping () -> Void) {
        self.icon = icon
        self.clickTogglesBoost = clickTogglesBoost
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        // The app logo, rounded like a macOS app tile.
        let logo = NSImageView()
        logo.image = icon
        logo.imageScaling = .scaleProportionallyUpOrDown
        logo.wantsLayer = true
        logo.layer?.cornerRadius = 11
        logo.layer?.masksToBounds = true
        logo.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logo.widthAnchor.constraint(equalToConstant: 52),
            logo.heightAnchor.constraint(equalToConstant: 52),
        ])

        let title = makeLabel("MaxCandela lives up here", size: 15, weight: .semibold)

        let body = makeLabel(Self.bodyText(clickTogglesBoost: clickTogglesBoost),
                             size: 13, weight: .regular)
        body.textColor = .secondaryLabelColor
        body.preferredMaxLayoutWidth = 260

        let button = NSButton(title: "Got it", target: self, action: #selector(dismissWelcome))
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"

        let stack = NSStackView(views: [logo, title, body, button])
        stack.orientation = .vertical
        stack.alignment = NSLayoutConstraint.Attribute.centerX
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            container.widthAnchor.constraint(equalToConstant: 300),
        ])
        view = container
    }

    /// Unit-tested: the popover must describe the click the app actually has.
    static func bodyText(clickTogglesBoost: Bool) -> String {
        let intro = "There’s no window or Dock icon — just this sun in your menu bar.\n\n"
        if clickTogglesBoost {
            return intro
                + "Click it to unlock your display’s full brightness, and click "
                + "again to go back.\n\n"
                + "Double-click (or right-click) for everything else: Extra Dim, "
                + "Warmth, Keep Awake, the timer, clipboard tools and more."
        }
        return intro
            + "Click it for your tools: the brightness boost, Extra Dim and "
            + "Warmth for your display, plus Keep Awake, a timer, clipboard "
            + "tools, a color picker, world clocks and a system read-out.\n\n"
            + "The display tools and the Pro tools — window snapping, hiding "
            + "menu bar icons, copying text off the screen and more — are free "
            + "to try for 5 days. The everyday tools are free to keep."
    }

    private func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }

    @objc private func dismissWelcome() {
        onDismiss()
    }
}
