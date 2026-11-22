import AppKit

/// The screenshot editor's drawing surface: shows the capture (cropped and
/// fitted, see `CanvasGeometry`) with its annotations, and turns drags,
/// clicks and typing into new annotations.
///
/// It never changes the document itself. A finished mark is handed to
/// `onChange`; the editor records it in its `EditHistory` and sets
/// `document` back — so every change, by mouse or by ⌘Z, takes one path.
final class AnnotationCanvasView: NSView, NSTextFieldDelegate, NSMenuItemValidation {
    let image: CGImage
    let pixelsPerPoint: CGFloat

    var document = AnnotationDocument() {
        didSet {
            if document.annotations != oldValue.annotations { flattened = nil }
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
        }
    }

    var tool: AnnotationTool = .arrow {
        didSet {
            commitText()
            cancelDrag()
            window?.invalidateCursorRects(for: self)
        }
    }
    var color: AnnotationColor = .red
    var size: AnnotationSize = .medium

    var onChange: ((AnnotationDocument) -> Void)?
    var onPickTool: ((AnnotationTool) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onCopy: (() -> Void)?
    var canUndo: () -> Bool = { false }
    var canRedo: () -> Bool = { false }

    /// The capture with its annotations; rebuilt only when they change.
    private var flattened: CGImage?
    private var dragStart: CGPoint?
    private var draft: Annotation?
    private var cropDraft: CGRect?
    private var textField: NSTextField?
    private var textAnchor: CGPoint?
    private var textStyle: (color: AnnotationColor, fontSize: CGFloat) = (.red, 20)

    init(image: CGImage, pixelsPerPoint: CGFloat) {
        self.image = image
        self.pixelsPerPoint = pixelsPerPoint
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var acceptsFirstResponder: Bool { true }

    private var fullRect: CGRect { CGRect(x: 0, y: 0, width: image.width, height: image.height) }

    var geometry: CanvasGeometry {
        CanvasGeometry(visible: document.crop ?? fullRect,
                       bounds: bounds.insetBy(dx: 20, dy: 20),
                       pixelsPerPoint: pixelsPerPoint)
    }

    /// Ends any text being typed, as an annotation. Call before exporting —
    /// a caption the user has typed but not confirmed is still meant.
    func finishEditing() { commitText() }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.underPageBackgroundColor.setFill()
        bounds.fill()
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let geometry = self.geometry
        let frame = geometry.imageFrame
        if flattened == nil { flattened = AnnotationRenderer.flatten(image, annotations: document.annotations) }

        context.saveGState()
        context.clip(to: frame)
        context.interpolationQuality = .high
        context.draw(flattened ?? image, in: geometry.toView(fullRect))
        if let draft {
            context.concatenate(geometry.imageToView)
            drawDraft(draft, in: context)
        }
        context.restoreGState()

        if let cropDraft { drawCropDraft(geometry.toView(cropDraft), in: frame) }

        NSColor.separatorColor.setStroke()
        NSBezierPath(rect: frame.insetBy(dx: -0.5, dy: -0.5)).stroke()
    }

    private func drawDraft(_ draft: Annotation, in context: CGContext) {
        guard case let .pixelate(rect, _) = draft else {
            AnnotationRenderer.draw(draft, in: context)
            return
        }
        // Real pixelation needs a bitmap to read back; while dragging, an
        // outline shows where it will go.
        context.setFillColor(CGColor(gray: 0.5, alpha: 0.3))
        context.fill(rect)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.9))
        context.setLineWidth(1 / geometry.scale)
        context.setLineDash(phase: 0, lengths: [4 / geometry.scale, 3 / geometry.scale])
        context.stroke(rect)
    }

    private func drawCropDraft(_ crop: CGRect, in frame: CGRect) {
        let outside = NSBezierPath(rect: frame)
        outside.append(NSBezierPath(rect: crop))
        outside.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.45).setFill()
        outside.fill()
        NSColor.white.setStroke()
        let outline = NSBezierPath(rect: crop.insetBy(dx: 0.5, dy: 0.5))
        outline.lineWidth = 1
        outline.stroke()
    }

    override func resetCursorRects() {
        addCursorRect(geometry.imageFrame, cursor: tool == .text ? .iBeam : .crosshair)
    }

    override func setFrameSize(_ newSize: NSSize) {
        // A field typed at the old scale would land in the wrong place.
        if newSize != frame.size { commitText() }
        super.setFrameSize(newSize)
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        // Taking first responder ends any text being typed, which commits it.
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let geometry = self.geometry
        if tool == .text {
            if geometry.imageFrame.contains(point) { beginText(at: point) }
            return
        }
        let start = geometry.toImageClamped(point)
        dragStart = start
        draft = tool == .highlighter
            ? .highlight([start], color: color, width: size.highlighterWidth * pixelsPerPoint)
            : nil
        cropDraft = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let point = geometry.toImageClamped(convert(event.locationInWindow, from: nil))
        let box = AnnotationGeometry.rect(from: start, to: point)
        let width = size.lineWidth * pixelsPerPoint
        switch tool {
        case .arrow:
            draft = .arrow(from: start, to: point, color: color, width: width)
        case .rectangle:
            draft = .rectangle(box, color: color, width: width)
        case .highlighter:
            if case let .highlight(points, color, width)? = draft,
               let last = points.last, hypot(point.x - last.x, point.y - last.y) >= 1 {
                draft = .highlight(points + [point], color: color, width: width)
            }
        case .pixelate:
            draft = .pixelate(box, blockSize: AnnotationGeometry.pixelateBlock(for: box, pixelsPerPoint: pixelsPerPoint))
        case .redact:
            draft = .redact(box)
        case .crop:
            cropDraft = box
        case .text:
            break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { cancelDrag() }
        guard dragStart != nil else { return }
        if tool == .crop {
            guard let cropDraft,
                  let crop = AnnotationGeometry.clampedCrop(cropDraft, within: geometry.visible) else { return }
            var next = document
            next.crop = crop
            onChange?(next)
            return
        }
        guard let draft, AnnotationGeometry.isWorthKeeping(draft) else { return }
        var next = document
        next.annotations.append(draft)
        onChange?(next)
    }

    private func cancelDrag() {
        dragStart = nil
        draft = nil
        cropDraft = nil
        needsDisplay = true
    }

    // MARK: - Text

    /// A borderless field where the text will go. AppKit handles the typing
    /// (input methods included); on Return the text becomes an annotation
    /// drawn by the renderer at the same place and size.
    private func beginText(at point: CGPoint) {
        commitText()
        let geometry = self.geometry
        let fontSize = size.fontSize * pixelsPerPoint
        let field = NSTextField(string: "")
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: fontSize * geometry.scale, weight: .semibold)
        field.textColor = NSColor(cgColor: color.cgColor())
        field.placeholderString = "Type, then press Return"
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.delegate = self
        field.sizeToFit()
        let height = field.frame.height
        // The field's cell insets its text ~2 pt; shift left so the first
        // glyph starts where the user clicked.
        field.frame = CGRect(x: point.x - 2, y: point.y - height,
                             width: max(120, geometry.imageFrame.maxX - point.x + 2), height: height)
        addSubview(field)
        window?.makeFirstResponder(field)
        textField = field
        textAnchor = geometry.toImage(point)
        textStyle = (color, fontSize)
    }

    private func commitText() {
        guard let field = textField, let anchor = textAnchor else { return }
        // Cleared first: removing the field ends its editing, which calls
        // back into here.
        textField = nil
        textAnchor = nil
        let string = field.stringValue.trimmingCharacters(in: .whitespaces)
        field.removeFromSuperview()
        guard !string.isEmpty else { return }
        var next = document
        next.annotations.append(.text(string, topLeft: anchor, color: textStyle.color, fontSize: textStyle.fontSize))
        onChange?(next)
    }

    private func cancelText() {
        guard let field = textField else { return }
        textField = nil
        textAnchor = nil
        field.removeFromSuperview()
        window?.makeFirstResponder(self)
    }

    func controlTextDidEndEditing(_ obj: Notification) { commitText() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            commitText()
            window?.makeFirstResponder(self)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            cancelText()
            return true
        default:
            return false
        }
    }

    // MARK: - Keyboard and Edit menu

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {    // Escape: drop the mark in progress
            cancelDrag()
            return
        }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        if modifiers.isEmpty, let key = event.charactersIgnoringModifiers?.lowercased().first,
           let picked = AnnotationTool.allCases.first(where: { $0.key == key }) {
            onPickTool?(picked)
            return
        }
        super.keyDown(with: event)
    }

    // undo:/redo: come from AppMenu's Edit menu (⌘Z / ⇧⌘Z). They are handled
    // here, by the first responder, because NSWindow answers them too — with
    // its own, empty, undo manager.
    @objc func undo(_ sender: Any?) {
        commitText()
        onUndo?()
    }

    @objc func redo(_ sender: Any?) { onRedo?() }

    @objc func copy(_ sender: Any?) { onCopy?() }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(undo(_:)): return canUndo() || textField != nil
        case #selector(redo(_:)): return canRedo()
        case #selector(copy(_:)): return true
        default: return false
        }
    }
}
