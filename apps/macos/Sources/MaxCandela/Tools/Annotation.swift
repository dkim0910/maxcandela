import CoreGraphics

/// The screenshot editor's data model: what the user drew, the crop, and the
/// undo history. Pure values and arithmetic — no AppKit — so every rule here
/// is unit-tested.
///
/// **One coordinate space for everything:** the captured image's pixels,
/// origin at the bottom-left, y up — the same space a `CGContext` over the
/// image draws in. Annotations stay put however the window is resized or
/// cropped, and export draws them at full resolution with no conversion.
/// The two places that need another space convert explicitly:
/// `CanvasGeometry` (the on-screen view) and `AnnotationGeometry.topLeftRect`
/// (`CGImage.cropping(to:)`, which counts from the top).

/// The editor's drawing tools, in toolbar order.
enum AnnotationTool: Int, CaseIterable {
    case arrow, rectangle, text, highlighter, pixelate, redact, crop

    var title: String {
        switch self {
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .text: return "Text"
        case .highlighter: return "Highlighter"
        case .pixelate: return "Pixelate"
        case .redact: return "Redact"
        case .crop: return "Crop"
        }
    }

    var symbol: String {
        switch self {
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .text: return "textformat"
        case .highlighter: return "highlighter"
        case .pixelate: return "checkerboard.rectangle"
        case .redact: return "rectangle.fill"
        case .crop: return "crop"
        }
    }

    /// Typed on the canvas to pick the tool.
    var key: Character {
        switch self {
        case .arrow: return "a"
        case .rectangle: return "r"
        case .text: return "t"
        case .highlighter: return "h"
        case .pixelate: return "p"
        case .redact: return "b"
        case .crop: return "c"
        }
    }

    var help: String {
        switch self {
        case .arrow: return "Arrow (A)"
        case .rectangle: return "Rectangle (R)"
        case .text: return "Text (T) — click, type, press Return"
        case .highlighter: return "Highlighter (H)"
        case .pixelate: return "Pixelate (P) — blurs detail out. For passwords and numbers use Redact, which can’t be undone"
        case .redact: return "Redact (B) — a solid black box"
        case .crop: return "Crop (C)"
        }
    }
}

/// A fixed palette: picking from six beats a colour panel for markup.
enum AnnotationColor: Int, CaseIterable {
    case red, orange, yellow, green, blue, black

    var title: String {
        switch self {
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .black: return "Black"
        }
    }

    /// sRGB components. Drawing converts them into the capture's own colour
    /// space, so red looks the same red on a P3 capture.
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        switch self {
        case .red: return (1.00, 0.23, 0.19)
        case .orange: return (1.00, 0.58, 0.00)
        case .yellow: return (1.00, 0.84, 0.04)
        case .green: return (0.20, 0.78, 0.35)
        case .blue: return (0.04, 0.52, 1.00)
        case .black: return (0, 0, 0)
        }
    }

    func cgColor(alpha: CGFloat = 1) -> CGColor {
        let c = components
        return CGColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: alpha)
    }
}

/// Stroke weight and text size, in points — multiplied by the capture's
/// pixels-per-point so a "medium" arrow looks the same on a Retina capture as
/// on a standard one.
enum AnnotationSize: Int, CaseIterable {
    case small, medium, large

    var title: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        }
    }

    var lineWidth: CGFloat { [2, 4, 7][rawValue] }
    var fontSize: CGFloat { [14, 20, 30][rawValue] }
    var highlighterWidth: CGFloat { [12, 20, 32][rawValue] }
}

/// One mark on the image. Coordinates in image pixels, bottom-left origin.
enum Annotation: Equatable {
    case arrow(from: CGPoint, to: CGPoint, color: AnnotationColor, width: CGFloat)
    case rectangle(CGRect, color: AnnotationColor, width: CGFloat)
    /// `topLeft` is the top-left corner of the line of text.
    case text(String, topLeft: CGPoint, color: AnnotationColor, fontSize: CGFloat)
    case highlight([CGPoint], color: AnnotationColor, width: CGFloat)
    case pixelate(CGRect, blockSize: CGFloat)
    case redact(CGRect)
}

/// Everything the user has done to one capture.
struct AnnotationDocument: Equatable {
    var annotations: [Annotation] = []
    /// Image pixels, bottom-left origin; nil = the whole capture.
    var crop: CGRect?
}

/// Linear undo/redo over whole snapshots. The states are small values (a few
/// marks), so snapshotting is simpler than inverse operations and cannot get
/// them wrong.
struct EditHistory<State: Equatable> {
    private(set) var current: State
    private var undoStack: [State] = []
    private var redoStack: [State] = []
    let limit: Int

    init(_ initial: State, limit: Int = 200) {
        current = initial
        self.limit = limit
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Records a new state. A change that changes nothing is not an undo
    /// step. A new change abandons whatever was undone before it.
    mutating func apply(_ state: State) {
        guard state != current else { return }
        undoStack.append(current)
        if undoStack.count > limit { undoStack.removeFirst(undoStack.count - limit) }
        redoStack.removeAll()
        current = state
    }

    mutating func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(current)
        current = previous
    }

    mutating func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(current)
        current = next
    }
}

/// Pure geometry for drawing and cropping.
enum AnnotationGeometry {
    /// The box a drag describes, whichever way it went.
    static func rect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    /// An arrowhead for a shaft from `from` to `to`: the tip is `to`, `base`
    /// is where the shaft should stop (so a thick line doesn't poke through
    /// the point), `left`/`right` are the barbs. Nil for a zero-length arrow.
    /// The head grows with the line but never past half the arrow, so a
    /// short arrow is still mostly shaft.
    static func arrowHead(from: CGPoint, to: CGPoint, lineWidth: CGFloat)
        -> (base: CGPoint, left: CGPoint, right: CGPoint)? {
        let dx = to.x - from.x, dy = to.y - from.y
        let length = hypot(dx, dy)
        guard length > 0 else { return nil }
        let headLength = min(max(lineWidth * 4.5, 8), length * 0.5)
        let halfWidth = headLength * 0.55
        let ux = dx / length, uy = dy / length
        let base = CGPoint(x: to.x - ux * headLength, y: to.y - uy * headLength)
        return (base,
                CGPoint(x: base.x - uy * halfWidth, y: base.y + ux * halfWidth),
                CGPoint(x: base.x + uy * halfWidth, y: base.y - ux * halfWidth))
    }

    /// A crop the user dragged, kept inside what is currently shown and
    /// snapped outward to whole pixels. Nil if too small to mean anything —
    /// a stray click with the crop tool must not crop to a sliver.
    static func clampedCrop(_ rect: CGRect, within visible: CGRect) -> CGRect? {
        let inside = rect.intersection(visible)
        guard !inside.isNull else { return nil }
        let minX = max(inside.minX.rounded(.down), visible.minX)
        let minY = max(inside.minY.rounded(.down), visible.minY)
        let maxX = min(inside.maxX.rounded(.up), visible.maxX)
        let maxY = min(inside.maxY.rounded(.up), visible.maxY)
        let result = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        return result.width >= 8 && result.height >= 8 ? result : nil
    }

    /// A rectangle in image pixels with the origin at the bottom → the same
    /// rectangle counted from the top, which `CGImage.cropping(to:)` wants.
    /// Getting this wrong crops the mirror-image band of the picture.
    static func topLeftRect(_ rect: CGRect, imageHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: imageHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// A mark too small to be anything but a stray click is dropped rather
    /// than left as an invisible undo step.
    static func isWorthKeeping(_ annotation: Annotation) -> Bool {
        switch annotation {
        case let .arrow(from, to, _, _): return hypot(to.x - from.x, to.y - from.y) >= 4
        case let .rectangle(rect, _, _), let .pixelate(rect, _), let .redact(rect):
            return rect.width >= 3 && rect.height >= 3
        case let .text(string, _, _, _): return !string.isEmpty
        case let .highlight(points, _, _): return !points.isEmpty
        }
    }

    /// Pixelation block size for a region: big enough that text inside
    /// becomes unreadable (at least ~6 points), bigger for big regions.
    static func pixelateBlock(for rect: CGRect, pixelsPerPoint: CGFloat) -> CGFloat {
        max((min(rect.width, rect.height) / 8).rounded(), 6 * pixelsPerPoint)
    }
}

/// Where the image sits in the editor's canvas view, and the conversion
/// between the two. The canvas shows `visible` (the crop, or the whole
/// image) centred and scaled to fit — but never above its natural size, so a
/// Retina capture is shown at the size it was on screen, not doubled.
struct CanvasGeometry: Equatable {
    /// Image pixels, bottom-left origin.
    let visible: CGRect
    /// The view area to fit into, view points.
    let bounds: CGRect
    let pixelsPerPoint: CGFloat

    /// View points per image pixel.
    var scale: CGFloat {
        guard visible.width > 0, visible.height > 0 else { return 1 }
        return min(bounds.width / visible.width, bounds.height / visible.height, 1 / max(pixelsPerPoint, 1e-6))
    }

    /// Where `visible` lands, view points.
    var imageFrame: CGRect {
        let size = CGSize(width: visible.width * scale, height: visible.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    func toView(_ point: CGPoint) -> CGPoint {
        let frame = imageFrame
        return CGPoint(x: frame.minX + (point.x - visible.minX) * scale,
                       y: frame.minY + (point.y - visible.minY) * scale)
    }

    func toView(_ rect: CGRect) -> CGRect {
        let origin = toView(rect.origin)
        return CGRect(x: origin.x, y: origin.y, width: rect.width * scale, height: rect.height * scale)
    }

    func toImage(_ point: CGPoint) -> CGPoint {
        let frame = imageFrame
        return CGPoint(x: visible.minX + (point.x - frame.minX) / scale,
                       y: visible.minY + (point.y - frame.minY) / scale)
    }

    /// Like `toImage`, but held inside the visible part — a drag that leaves
    /// the picture draws to its edge, not off into nothing.
    func toImageClamped(_ point: CGPoint) -> CGPoint {
        let p = toImage(point)
        return CGPoint(x: min(max(p.x, visible.minX), visible.maxX),
                       y: min(max(p.y, visible.minY), visible.maxY))
    }

    /// The CTM that makes drawing in image pixels land in view points.
    var imageToView: CGAffineTransform {
        let frame = imageFrame
        return CGAffineTransform(translationX: frame.minX, y: frame.minY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -visible.minX, y: -visible.minY)
    }
}
