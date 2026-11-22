import AppKit
import UniformTypeIdentifiers

/// The window a capture opens in: a toolbar of markup tools over the canvas,
/// with Copy and Save….
///
/// Nothing is written anywhere unless the user saves, and then only to the
/// file they chose in the save panel (the sandbox's user-selected-file
/// entitlement covers exactly that). Closing the window discards the capture.
///
/// Keys: the tool letters (see `AnnotationTool.key`), ⌘Z / ⇧⌘Z, ⌘C copies
/// the picture, ⌘S saves, ⌘W closes.
final class ScreenshotEditor: NSObject, NSWindowDelegate {
    var onClose: ((ScreenshotEditor) -> Void)?

    private let shot: ScreenImage
    private let capturedAt: Date
    private let window: EditorWindow
    private let canvas: AnnotationCanvasView
    private var history = EditHistory(AnnotationDocument())

    private let toolPicker = NSSegmentedControl()
    private let colorPicker = NSPopUpButton()
    private let sizePicker = NSSegmentedControl()
    private let undoButton = NSButton()
    private let redoButton = NSButton()
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save…", target: nil, action: nil)

    private static let toolKey = "com.maxcandela.screenshot.tool"
    private static let colorKey = "com.maxcandela.screenshot.color"
    private static let sizeKey = "com.maxcandela.screenshot.size"

    init(shot: ScreenImage, capturedAt: Date = Date()) {
        self.shot = shot
        self.capturedAt = capturedAt
        canvas = AnnotationCanvasView(image: shot.image, pixelsPerPoint: shot.pixelsPerPoint)
        window = EditorWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        super.init()

        window.title = "Screenshot"
        window.subtitle = "\(shot.image.width) × \(shot.image.height) pixels"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentMinSize = Self.minimumContentSize

        buildToolbar()
        // The spacer is the one view allowed to stretch, pushing the history
        // and export buttons to the trailing edge.
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let toolbar = NSStackView(views: [toolPicker, colorPicker, sizePicker, spacer,
                                          undoButton, redoButton, copyButton, saveButton])
        toolbar.orientation = .horizontal
        toolbar.distribution = .fill
        toolbar.spacing = 8
        toolbar.setCustomSpacing(16, after: sizePicker)
        toolbar.setCustomSpacing(16, after: redoButton)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        canvas.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(toolbar)
        content.addSubview(canvas)
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
            toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            toolbar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            canvas.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 10),
            canvas.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            canvas.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
        window.setContentSize(Self.initialContentSize(for: shot, on: NSScreen.main))

        canvas.onChange = { [weak self] in self?.record($0) }
        canvas.onPickTool = { [weak self] in self?.select(tool: $0) }
        canvas.onUndo = { [weak self] in self?.undo() }
        canvas.onRedo = { [weak self] in self?.redo() }
        canvas.onCopy = { [weak self] in self?.copyImage() }
        canvas.canUndo = { [weak self] in self?.history.canUndo ?? false }
        canvas.canRedo = { [weak self] in self?.history.canRedo ?? false }

        select(tool: AnnotationTool(rawValue: UserDefaults.standard.integer(forKey: Self.toolKey)) ?? .arrow)
        let color = AnnotationColor(rawValue: UserDefaults.standard.integer(forKey: Self.colorKey)) ?? .red
        colorPicker.selectItem(at: color.rawValue)
        canvas.color = color
        let size = UserDefaults.standard.object(forKey: Self.sizeKey) as? Int ?? AnnotationSize.medium.rawValue
        sizePicker.selectedSegment = size
        canvas.size = AnnotationSize(rawValue: size) ?? .medium
        updateButtons()
    }

    /// Room for the whole toolbar.
    static let minimumContentSize = NSSize(width: 760, height: 420)

    /// The capture at the size it had on screen, plus the toolbar — but no
    /// more than most of the screen, and no less than the minimum.
    static func initialContentSize(for shot: ScreenImage, on screen: NSScreen?) -> NSSize {
        let natural = NSSize(width: CGFloat(shot.image.width) / shot.pixelsPerPoint + 40,
                             height: CGFloat(shot.image.height) / shot.pixelsPerPoint + 40 + 52)
        let limit = screen?.visibleFrame.size ?? NSSize(width: 1200, height: 800)
        return NSSize(width: min(max(natural.width, minimumContentSize.width), limit.width * 0.85),
                      height: min(max(natural.height, minimumContentSize.height), limit.height * 0.85))
    }

    func show() {
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(canvas)
    }

    func close() { window.close() }

    func windowWillClose(_ notification: Notification) {
        onClose?(self)
    }

    // MARK: - Toolbar

    private func buildToolbar() {
        toolPicker.segmentCount = AnnotationTool.allCases.count
        toolPicker.trackingMode = .selectOne
        for tool in AnnotationTool.allCases {
            let image = NSImage(systemSymbolName: tool.symbol, accessibilityDescription: tool.title)
            toolPicker.setImage(image, forSegment: tool.rawValue)
            toolPicker.setToolTip(tool.help, forSegment: tool.rawValue)
            toolPicker.setWidth(32, forSegment: tool.rawValue)
        }
        toolPicker.target = self
        toolPicker.action = #selector(toolChanged)

        for color in AnnotationColor.allCases {
            colorPicker.addItem(withTitle: color.title)
            colorPicker.lastItem?.image = Self.swatch(color)
        }
        colorPicker.target = self
        colorPicker.action = #selector(colorChanged)
        colorPicker.toolTip = "Colour for arrows, boxes, text and the highlighter"

        sizePicker.segmentCount = AnnotationSize.allCases.count
        sizePicker.trackingMode = .selectOne
        for size in AnnotationSize.allCases {
            sizePicker.setLabel(size.title, forSegment: size.rawValue)
            sizePicker.setWidth(26, forSegment: size.rawValue)
        }
        sizePicker.toolTip = "Line and text size"
        sizePicker.target = self
        sizePicker.action = #selector(sizeChanged)

        configure(undoButton, symbol: "arrow.uturn.backward", tip: "Undo (⌘Z)", action: #selector(undoClicked))
        configure(redoButton, symbol: "arrow.uturn.forward", tip: "Redo (⇧⌘Z)", action: #selector(redoClicked))

        copyButton.target = self
        copyButton.action = #selector(copyClicked)
        copyButton.toolTip = "Copy the picture to the clipboard (⌘C)"
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        saveButton.keyEquivalent = "s"
        saveButton.keyEquivalentModifierMask = .command
        saveButton.toolTip = "Save as PNG (⌘S)"
    }

    private func configure(_ button: NSButton, symbol: String, tip: String, action: Selector) {
        button.bezelStyle = .rounded
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
        button.imagePosition = .imageOnly
        button.toolTip = tip
        button.target = self
        button.action = action
    }

    private static func swatch(_ color: AnnotationColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            NSColor(cgColor: color.cgColor())?.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            NSColor.separatorColor.setStroke()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).stroke()
            return true
        }
    }

    private func select(tool: AnnotationTool) {
        toolPicker.selectedSegment = tool.rawValue
        canvas.tool = tool
        UserDefaults.standard.set(tool.rawValue, forKey: Self.toolKey)
    }

    @objc private func toolChanged() {
        select(tool: AnnotationTool(rawValue: toolPicker.selectedSegment) ?? .arrow)
        window.makeFirstResponder(canvas)
    }

    @objc private func colorChanged() {
        let color = AnnotationColor(rawValue: colorPicker.indexOfSelectedItem) ?? .red
        canvas.color = color
        UserDefaults.standard.set(color.rawValue, forKey: Self.colorKey)
        window.makeFirstResponder(canvas)
    }

    @objc private func sizeChanged() {
        let size = AnnotationSize(rawValue: sizePicker.selectedSegment) ?? .medium
        canvas.size = size
        UserDefaults.standard.set(size.rawValue, forKey: Self.sizeKey)
        window.makeFirstResponder(canvas)
    }

    // MARK: - History

    private func record(_ document: AnnotationDocument) {
        history.apply(document)
        canvas.document = history.current
        updateButtons()
    }

    private func undo() {
        history.undo()
        canvas.document = history.current
        updateButtons()
    }

    private func redo() {
        history.redo()
        canvas.document = history.current
        updateButtons()
    }

    private func updateButtons() {
        undoButton.isEnabled = history.canUndo
        redoButton.isEnabled = history.canRedo
    }

    @objc private func undoClicked() {
        canvas.finishEditing()
        undo()
    }

    @objc private func redoClicked() { redo() }

    // MARK: - Export

    private func finishedImage() -> CGImage? {
        canvas.finishEditing()
        return AnnotationRenderer.render(shot.image, document: history.current)
    }

    @objc private func copyClicked() { copyImage() }

    private func copyImage() {
        guard let image = finishedImage(),
              ImageExport.copy(image, pixelsPerPoint: shot.pixelsPerPoint) else {
            NSSound.beep()
            return
        }
        copyButton.title = "Copied"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.copyButton.title = "Copy"
        }
    }

    @objc private func saveClicked() {
        guard let image = finishedImage(),
              let data = ImageExport.pngData(image, pixelsPerPoint: shot.pixelsPerPoint) else {
            NSSound.beep()
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = ImageExport.fileName(for: capturedAt)
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
            } catch {
                guard let window = self?.window else { return }
                NSAlert(error: error).beginSheetModal(for: window)
            }
        }
    }
}

/// The editor's window. An accessory app has no File menu for ⌘W to find,
/// so the window answers it itself.
private final class EditorWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command, event.charactersIgnoringModifiers == "w" {
            performClose(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
