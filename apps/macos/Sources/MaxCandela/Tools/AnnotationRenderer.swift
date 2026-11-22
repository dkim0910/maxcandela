import AppKit

/// Draws annotations onto a capture. One code path for the canvas and for
/// export, so what the user sees in the editor is what Copy and Save produce.
/// Headless (bitmap contexts only), which is what lets the tests check
/// actual pixels.
enum AnnotationRenderer {

    /// The finished picture: every annotation drawn at full resolution, then
    /// the crop applied. What Copy and Save hand out.
    static func render(_ image: CGImage, document: AnnotationDocument) -> CGImage? {
        guard let flat = flatten(image, annotations: document.annotations) else { return nil }
        guard let crop = document.crop else { return flat }
        return flat.cropping(to: AnnotationGeometry.topLeftRect(crop, imageHeight: CGFloat(flat.height)))
    }

    /// The capture with its annotations, uncropped — the canvas frames the
    /// crop itself, so it re-renders only when an annotation changes.
    static func flatten(_ image: CGImage, annotations: [Annotation]) -> CGImage? {
        guard let context = makeContext(width: image.width, height: image.height,
                                        colorSpace: drawableColorSpace(of: image)) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        annotations.forEach { draw($0, in: context) }
        return context.makeImage()
    }

    /// The capture's own colour space when it can be drawn into (a display
    /// profile usually can), so the export is not converted twice.
    static func drawableColorSpace(of image: CGImage) -> CGColorSpace {
        if let space = image.colorSpace, space.model == .rgb, space.supportsOutput { return space }
        return CGColorSpace(name: CGColorSpace.sRGB)!
    }

    static func makeContext(width: Int, height: Int, colorSpace: CGColorSpace) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    /// One annotation, in whatever space the context's CTM maps image pixels
    /// to. Pixelate reads back what is already drawn, so it needs a bitmap
    /// context; elsewhere (the canvas preview) it is drawn as an outline.
    static func draw(_ annotation: Annotation, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        switch annotation {
        case let .arrow(from, to, color, width):
            drawArrow(from: from, to: to, color: color, width: width, in: context)

        case let .rectangle(rect, color, width):
            context.setStrokeColor(color.cgColor())
            context.setLineWidth(width)
            context.setLineJoin(.miter)
            context.stroke(rect)

        case let .text(string, topLeft, color, fontSize):
            drawText(string, topLeft: topLeft, color: color, fontSize: fontSize, in: context)

        case let .highlight(points, color, width):
            guard let first = points.first else { return }
            // Multiply, like ink on paper: dark text under the stroke stays dark.
            context.setBlendMode(.multiply)
            context.setStrokeColor(color.cgColor(alpha: 0.45))
            context.setLineWidth(width)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.move(to: first)
            if points.count == 1 {
                context.addLine(to: first)
            } else {
                points.dropFirst().forEach { context.addLine(to: $0) }
            }
            context.strokePath()

        case let .pixelate(rect, blockSize):
            pixelate(rect, blockSize: blockSize, in: context)

        case let .redact(rect):
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(rect)
        }
    }

    private static func drawArrow(from: CGPoint, to: CGPoint, color: AnnotationColor,
                                  width: CGFloat, in context: CGContext) {
        guard let head = AnnotationGeometry.arrowHead(from: from, to: to, lineWidth: width) else { return }
        context.setStrokeColor(color.cgColor())
        context.setFillColor(color.cgColor())
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.move(to: from)
        context.addLine(to: head.base)
        context.strokePath()
        context.move(to: to)
        context.addLine(to: head.left)
        context.addLine(to: head.right)
        context.closePath()
        context.fillPath()
    }

    static func textAttributes(color: AnnotationColor, fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
         .foregroundColor: NSColor(cgColor: color.cgColor()) ?? .red]
    }

    private static func drawText(_ string: String, topLeft: CGPoint, color: AnnotationColor,
                                 fontSize: CGFloat, in context: CGContext) {
        let text = NSAttributedString(string: string, attributes: textAttributes(color: color, fontSize: fontSize))
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        // Unflipped, draw(at:) places the line's bottom-left at the point.
        text.draw(at: CGPoint(x: topLeft.x, y: topLeft.y - text.size().height))
        NSGraphicsContext.current = previous
    }

    /// Replaces a region with blocks of its own average colour. Built from a
    /// downscale (one pixel per block) drawn back up without interpolation,
    /// so each block is uniform and nothing of the original detail survives
    /// in the output pixels.
    static func pixelate(_ rect: CGRect, blockSize: CGFloat, in context: CGContext) {
        let canvas = CGRect(x: 0, y: 0, width: context.width, height: context.height)
        let region = rect.integral.intersection(canvas)
        guard !region.isNull, !region.isEmpty, let snapshot = context.makeImage(),
              let source = snapshot.cropping(to: AnnotationGeometry.topLeftRect(region, imageHeight: canvas.height))
        else { return }
        let block = max(1, blockSize)
        let columns = max(1, Int((region.width / block).rounded(.up)))
        let rows = max(1, Int((region.height / block).rounded(.up)))
        guard let small = makeContext(width: columns, height: rows,
                                      colorSpace: context.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!)
        else { return }
        small.interpolationQuality = .high
        small.draw(source, in: CGRect(x: 0, y: 0, width: columns, height: rows))
        guard let blocks = small.makeImage() else { return }
        // Bitmap contexts start with an identity CTM, so `region` is in the
        // same pixels the snapshot was cut from.
        context.interpolationQuality = .none
        context.setBlendMode(.copy)
        context.draw(blocks, in: region)
    }
}
