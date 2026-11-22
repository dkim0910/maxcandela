import AppKit
import ImageIO
import XCTest
@testable import MaxCandela

/// The screenshot editor without its window: the undo history, the geometry,
/// the view ↔ image mapping, and the renderer — checked on real pixels,
/// because "the crop took the mirror-image band" and "pixelation left the
/// text readable" are both bugs that look fine in code review.
final class AnnotationTests: XCTestCase {

    // MARK: - Undo history

    func testUndoRedoWalkTheHistory() {
        var history = EditHistory(0)
        XCTAssertFalse(history.canUndo)
        history.apply(1)
        history.apply(2)
        history.apply(2)                          // no change, no undo step
        history.undo()
        XCTAssertEqual(history.current, 1)
        history.undo()
        XCTAssertEqual(history.current, 0)
        history.undo()                            // nothing left: stays put
        XCTAssertEqual(history.current, 0)
        XCTAssertFalse(history.canUndo)
        history.redo()
        XCTAssertEqual(history.current, 1)
        XCTAssertTrue(history.canRedo)
        history.apply(5)                          // a new change abandons the redo
        XCTAssertFalse(history.canRedo)
        history.undo()
        XCTAssertEqual(history.current, 1)
    }

    func testHistoryKeepsOnlyTheNewestSteps() {
        var history = EditHistory(0, limit: 3)
        for value in 1...10 { history.apply(value) }
        history.undo(); history.undo(); history.undo()
        XCTAssertEqual(history.current, 7)
        XCTAssertFalse(history.canUndo)
    }

    // MARK: - Geometry

    func testADragDescribesTheSameBoxEitherWay() {
        let expected = CGRect(x: 10, y: 20, width: 30, height: 40)
        XCTAssertEqual(AnnotationGeometry.rect(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 40, y: 60)), expected)
        XCTAssertEqual(AnnotationGeometry.rect(from: CGPoint(x: 40, y: 60), to: CGPoint(x: 10, y: 20)), expected)
        XCTAssertEqual(AnnotationGeometry.rect(from: CGPoint(x: 40, y: 20), to: CGPoint(x: 10, y: 60)), expected)
    }

    func testArrowheadSitsOnTheTipAndIsSymmetric() throws {
        let head = try XCTUnwrap(AnnotationGeometry.arrowHead(from: .zero, to: CGPoint(x: 100, y: 0), lineWidth: 4))
        // Head length 4.5 × width = 18, barbs 0.55 × that either side.
        XCTAssertEqual(head.base.x, 82, accuracy: 0.001)
        XCTAssertEqual(head.base.y, 0, accuracy: 0.001)
        XCTAssertEqual(head.left.y, 9.9, accuracy: 0.001)
        XCTAssertEqual(head.right.y, -9.9, accuracy: 0.001)

        // Any direction: the barbs are equally far from the tip.
        let tip = CGPoint(x: -30, y: 70)
        let diagonal = try XCTUnwrap(AnnotationGeometry.arrowHead(from: CGPoint(x: 50, y: 10), to: tip, lineWidth: 6))
        XCTAssertEqual(hypot(diagonal.left.x - tip.x, diagonal.left.y - tip.y),
                       hypot(diagonal.right.x - tip.x, diagonal.right.y - tip.y), accuracy: 0.001)

        // A short arrow keeps half its length as shaft.
        let short = try XCTUnwrap(AnnotationGeometry.arrowHead(from: .zero, to: CGPoint(x: 10, y: 0), lineWidth: 4))
        XCTAssertEqual(short.base.x, 5, accuracy: 0.001)
        XCTAssertNil(AnnotationGeometry.arrowHead(from: .zero, to: .zero, lineWidth: 4))
    }

    func testStrayClicksAreNotKept() {
        XCTAssertFalse(AnnotationGeometry.isWorthKeeping(.arrow(from: .zero, to: CGPoint(x: 2, y: 0), color: .red, width: 4)))
        XCTAssertTrue(AnnotationGeometry.isWorthKeeping(.arrow(from: .zero, to: CGPoint(x: 20, y: 0), color: .red, width: 4)))
        XCTAssertFalse(AnnotationGeometry.isWorthKeeping(.redact(CGRect(x: 0, y: 0, width: 2, height: 50))))
        XCTAssertTrue(AnnotationGeometry.isWorthKeeping(.pixelate(CGRect(x: 0, y: 0, width: 30, height: 30), blockSize: 8)))
        XCTAssertFalse(AnnotationGeometry.isWorthKeeping(.text("", topLeft: .zero, color: .red, fontSize: 20)))
    }

    func testCropStaysInsideWhatIsShownOnWholePixels() {
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
        XCTAssertEqual(AnnotationGeometry.clampedCrop(CGRect(x: 10.4, y: 20.6, width: 100.2, height: 50.1), within: visible),
                       CGRect(x: 10, y: 20, width: 101, height: 51))
        // Dragged past the edge of the picture.
        XCTAssertEqual(AnnotationGeometry.clampedCrop(CGRect(x: 900, y: 700, width: 300, height: 300), within: visible),
                       CGRect(x: 900, y: 700, width: 100, height: 100))
        // Cropping again can only go inside the earlier crop.
        let earlier = CGRect(x: 100, y: 100, width: 200, height: 200)
        XCTAssertEqual(AnnotationGeometry.clampedCrop(CGRect(x: 50, y: 50, width: 400, height: 400), within: earlier), earlier)
        // A click, not a crop.
        XCTAssertNil(AnnotationGeometry.clampedCrop(CGRect(x: 10, y: 10, width: 5, height: 50), within: visible))
        XCTAssertNil(AnnotationGeometry.clampedCrop(CGRect(x: 2000, y: 10, width: 50, height: 50), within: visible))
    }

    func testCroppingCountsFromTheTop() {
        // CGImage.cropping(to:) measures from the top; the document from the bottom.
        XCTAssertEqual(AnnotationGeometry.topLeftRect(CGRect(x: 10, y: 20, width: 100, height: 50), imageHeight: 800),
                       CGRect(x: 10, y: 730, width: 100, height: 50))
    }

    func testPixelationBlocksAreNeverFine() {
        // A one-line password field on a Retina capture: at least 6 pt blocks.
        XCTAssertEqual(AnnotationGeometry.pixelateBlock(for: CGRect(x: 0, y: 0, width: 400, height: 40), pixelsPerPoint: 2), 12)
        // A big region gets coarser blocks.
        XCTAssertEqual(AnnotationGeometry.pixelateBlock(for: CGRect(x: 0, y: 0, width: 400, height: 400), pixelsPerPoint: 2), 50)
    }

    // MARK: - Canvas mapping

    func testRetinaCaptureIsShownAtItsNaturalSizeCentred() {
        // 1440 × 900 pt captured at 2×, in a canvas with room to spare.
        let geometry = CanvasGeometry(visible: CGRect(x: 0, y: 0, width: 2880, height: 1800),
                                      bounds: CGRect(x: 0, y: 0, width: 2000, height: 1500), pixelsPerPoint: 2)
        XCTAssertEqual(geometry.scale, 0.5)
        XCTAssertEqual(geometry.imageFrame, CGRect(x: 280, y: 300, width: 1440, height: 900))
    }

    func testCaptureShrinksToFitASmallCanvas() {
        let geometry = CanvasGeometry(visible: CGRect(x: 0, y: 0, width: 2880, height: 1800),
                                      bounds: CGRect(x: 0, y: 0, width: 720, height: 900), pixelsPerPoint: 2)
        XCTAssertEqual(geometry.scale, 0.25)
        XCTAssertEqual(geometry.imageFrame, CGRect(x: 0, y: 225, width: 720, height: 450))
    }

    func testCroppedCanvasMapsBothWays() {
        let geometry = CanvasGeometry(visible: CGRect(x: 1000, y: 500, width: 400, height: 200),
                                      bounds: CGRect(x: 0, y: 0, width: 800, height: 600), pixelsPerPoint: 1)
        XCTAssertEqual(geometry.imageFrame, CGRect(x: 200, y: 200, width: 400, height: 200))
        XCTAssertEqual(geometry.toView(CGPoint(x: 1000, y: 500)), CGPoint(x: 200, y: 200))
        XCTAssertEqual(geometry.toImage(CGPoint(x: 300, y: 250)), CGPoint(x: 1100, y: 550))
        // Outside the picture, a drag is held to its edge.
        XCTAssertEqual(geometry.toImageClamped(.zero), CGPoint(x: 1000, y: 500))
        // The drawing transform agrees with the point conversion.
        let p = CGPoint(x: 1234, y: 567)
        XCTAssertEqual(p.applying(geometry.imageToView).x, geometry.toView(p).x, accuracy: 0.0001)
        XCTAssertEqual(p.applying(geometry.imageToView).y, geometry.toView(p).y, accuracy: 0.0001)
    }

    func testViewAndImageRoundTrip() {
        let geometry = CanvasGeometry(visible: CGRect(x: 0, y: 0, width: 3024, height: 1964),
                                      bounds: CGRect(x: 20, y: 20, width: 977, height: 611), pixelsPerPoint: 2)
        for point in [CGPoint(x: 0, y: 0), CGPoint(x: 1512, y: 982), CGPoint(x: 3024, y: 1964), CGPoint(x: 17.5, y: 1900.25)] {
            let back = geometry.toImage(geometry.toView(point))
            XCTAssertEqual(back.x, point.x, accuracy: 0.0001)
            XCTAssertEqual(back.y, point.y, accuracy: 0.0001)
        }
    }

    // MARK: - Rendering (real pixels)

    private let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    private func makeImage(width: Int, height: Int, _ paint: (CGContext) -> Void) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        paint(context)
        return context.makeImage()!
    }

    private func solid(width: Int, height: Int, gray: CGFloat = 1) -> CGImage {
        makeImage(width: width, height: height) {
            $0.setFillColor(CGColor(srgbRed: gray, green: gray, blue: gray, alpha: 1))
            $0.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    /// RGBA at (x, y) counted from the TOP-left, as images are stored.
    private func pixel(_ image: CGImage, x: Int, yFromTop: Int) -> [UInt8] {
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: sRGB,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        let offset = yFromTop * image.width * 4 + x * 4
        return Array(UnsafeBufferPointer(start: bytes + offset, count: 4))
    }

    func testRedactIsSolidBlackOnlyWhereDrawn() throws {
        let image = solid(width: 100, height: 100)
        var document = AnnotationDocument()
        document.annotations = [.redact(CGRect(x: 10, y: 10, width: 20, height: 20))]   // bottom-left corner
        let output = try XCTUnwrap(AnnotationRenderer.render(image, document: document))
        XCTAssertEqual(pixel(output, x: 20, yFromTop: 80), [0, 0, 0, 255])
        XCTAssertEqual(pixel(output, x: 20, yFromTop: 20), [255, 255, 255, 255])   // the top-left is untouched
    }

    func testCropKeepsTheBandTheUserChose() throws {
        // Bottom half red, top half blue.
        let image = makeImage(width: 100, height: 100) {
            $0.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
            $0.fill(CGRect(x: 0, y: 0, width: 100, height: 50))
            $0.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
            $0.fill(CGRect(x: 0, y: 50, width: 100, height: 50))
        }
        var document = AnnotationDocument()
        document.crop = CGRect(x: 0, y: 0, width: 100, height: 40)   // the bottom (red) band
        let output = try XCTUnwrap(AnnotationRenderer.render(image, document: document))
        XCTAssertEqual(output.width, 100)
        XCTAssertEqual(output.height, 40)
        XCTAssertEqual(pixel(output, x: 50, yFromTop: 0), [255, 0, 0, 255])
        XCTAssertEqual(pixel(output, x: 50, yFromTop: 39), [255, 0, 0, 255])
    }

    func testPixelationLeavesUniformBlocksAndNothingElse() throws {
        // Every pixel different, like text.
        let image = makeImage(width: 64, height: 64) { context in
            for x in 0..<64 {
                for y in 0..<64 {
                    context.setFillColor(CGColor(srgbRed: CGFloat(x) / 63, green: CGFloat(y) / 63,
                                                 blue: CGFloat((x * 7 + y * 13) % 64) / 63, alpha: 1))
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        var document = AnnotationDocument()
        document.annotations = [.pixelate(CGRect(x: 16, y: 16, width: 32, height: 32), blockSize: 16)]
        let output = try XCTUnwrap(AnnotationRenderer.render(image, document: document))
        // Region (16…48) in both directions = rows 16…47 from the top too. Each 16×16 block is one colour.
        for (blockX, blockY) in [(16, 16), (32, 16), (16, 32), (32, 32)] {
            let reference = pixel(output, x: blockX, yFromTop: blockY)
            for dx in stride(from: 0, to: 16, by: 5) {
                for dy in stride(from: 0, to: 16, by: 5) {
                    XCTAssertEqual(pixel(output, x: blockX + dx, yFromTop: blockY + dy), reference)
                }
            }
        }
        XCTAssertNotEqual(pixel(output, x: 16, yFromTop: 16), pixel(output, x: 32, yFromTop: 32))
        // Outside the region, the original pixels.
        XCTAssertEqual(pixel(output, x: 2, yFromTop: 2), pixel(image, x: 2, yFromTop: 2))
        XCTAssertEqual(pixel(output, x: 60, yFromTop: 60), pixel(image, x: 60, yFromTop: 60))
    }

    func testTextHangsBelowItsAnchor() throws {
        let image = solid(width: 200, height: 100)
        var document = AnnotationDocument()
        // Anchor 20 px below the top of the image.
        document.annotations = [.text("H", topLeft: CGPoint(x: 20, y: 80), color: .black, fontSize: 40)]
        let output = try XCTUnwrap(AnnotationRenderer.render(image, document: document))
        func inkInRows(_ rows: Range<Int>) -> Bool {
            rows.contains { y in (0..<200).contains { x in pixel(output, x: x, yFromTop: y)[0] < 128 } }
        }
        XCTAssertFalse(inkInRows(0..<20), "text drawn above its anchor")
        XCTAssertTrue(inkInRows(20..<70), "no text where it should be")
    }

    func testHighlighterTintsWithoutHidingWhatIsUnder() throws {
        let image = solid(width: 60, height: 60)
        var document = AnnotationDocument()
        document.annotations = [.highlight([CGPoint(x: 5, y: 30), CGPoint(x: 55, y: 30)], color: .yellow, width: 20)]
        let output = try XCTUnwrap(AnnotationRenderer.render(image, document: document))
        let tinted = pixel(output, x: 30, yFromTop: 30)
        XCTAssertGreaterThan(tinted[0], 240)        // red stays
        XCTAssertLessThan(tinted[2], 200)           // blue drops: yellow
        XCTAssertGreaterThan(tinted[2], 100)        // but translucent, not paint
        XCTAssertEqual(pixel(output, x: 30, yFromTop: 2), [255, 255, 255, 255])
    }

    // MARK: - Export

    func testPNGRecordsRetinaResolution() throws {
        let data = try XCTUnwrap(ImageExport.pngData(solid(width: 40, height: 20), pixelsPerPoint: 2))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual((properties[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue ?? 0, 144, accuracy: 0.5)
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 40)
    }

    func testCopyPutsPNGAndTIFFOnThePasteboard() throws {
        // A private pasteboard: the user's clipboard is not touched.
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.maxcandela.tests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        XCTAssertTrue(ImageExport.copy(solid(width: 30, height: 10), pixelsPerPoint: 2, to: pasteboard))
        XCTAssertNotNil(pasteboard.data(forType: .png))
        XCTAssertNotNil(pasteboard.data(forType: .tiff))
        let image = try XCTUnwrap(NSImage(data: try XCTUnwrap(pasteboard.data(forType: .png))))
        XCTAssertEqual(image.size, NSSize(width: 15, height: 5))   // points, from the DPI
    }

    func testFileNameFollowsMacOSWithoutColons() {
        let date = Date(timeIntervalSince1970: 1_795_363_512)   // 2026-11-22 16:05:12 UTC
        XCTAssertEqual(ImageExport.fileName(for: date, timeZone: TimeZone(identifier: "UTC")!),
                       "Screenshot 2026-11-22 at 16.05.12.png")
    }

    func testEditorOpensAtNaturalSizeWithinLimits() {
        let big = ScreenImage(image: solid(width: 2880, height: 1800), pixelsPerPoint: 2)
        XCTAssertEqual(ScreenshotEditor.initialContentSize(for: big, on: nil), NSSize(width: 1020, height: 680))
        let small = ScreenImage(image: solid(width: 200, height: 100), pixelsPerPoint: 2)
        XCTAssertEqual(ScreenshotEditor.initialContentSize(for: small, on: nil), ScreenshotEditor.minimumContentSize)
    }
}
