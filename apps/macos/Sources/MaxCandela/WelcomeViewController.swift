import AppKit

/// The first-run callout shown in a popover anchored to the menu-bar ☀️ icon.
/// Its whole job is to tell the user "the app lives up here" — menu-bar apps
/// have no window or Dock icon, so first-timers otherwise can't find them.
final class WelcomeViewController: NSViewController {
    private let onDismiss: () -> Void
    private let icon: NSImage?

    init(icon: NSImage?, onDismiss: @escaping () -> Void) {
        self.icon = icon
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

        let body = makeLabel(
            "There’s no window or Dock icon — just this sun in your menu bar.\n\n"
            + "Click it to open the menu: turn the boost on or off, see your "
            + "trial status and purchase options, and quit the app.",
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
