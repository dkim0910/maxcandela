import XCTest
@testable import MaxCandela

/// QR codes both ways: Generate ▸ QR Code from Clipboard makes them, and
/// Copy Text / Scan QR Code from Screen read them. The round trip runs the
/// same Vision reader the screen tools use, on a code the generator made —
/// so a code we hand out is one a scanner can actually read.
final class QRCodeTests: XCTestCase {

    // MARK: - Making

    func testGeneratedCodeScansBackToTheClipboardText() throws {
        for text in ["https://maxcandela.com", "안녕하세요 — héllo wörld"] {
            // Surrounding whitespace (a newline copied from a terminal) is not encoded.
            let image = try XCTUnwrap(QRCode.image(for: "  \(text)\n"))
            XCTAssertEqual(image.width, image.height)
            XCTAssertEqual(try ScreenTextTool.readCodes(in: image), [text])
        }
    }

    func testCodeHasTheFullQuietZoneAndCrispModules() throws {
        // 22 bytes → a 25-module code; the generator adds 1 module a side and
        // we add 3 more, for the 4 the QR spec asks for: 33 modules.
        let image = try XCTUnwrap(QRCode.image(for: "https://maxcandela.com"))
        let module = QRCode.moduleSize(forModules: 33)
        XCTAssertEqual(image.width, 33 * module)

        let gray = CGColorSpaceCreateDeviceGray()
        let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                              bytesPerRow: image.width, space: gray,
                                              bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        func value(x: Int, y: Int) -> UInt8 { bytes[y * image.width + x] }
        let quiet = 4 * module
        for i in stride(from: 0, to: image.width, by: 7) {
            for edge in [0, quiet - 1] {
                XCTAssertEqual(value(x: i, y: edge), 255)                 // top band
                XCTAssertEqual(value(x: edge, y: i), 255)                 // left band
                XCTAssertEqual(value(x: i, y: image.height - 1 - edge), 255)
                XCTAssertEqual(value(x: image.width - 1 - edge, y: i), 255)
            }
        }
        // Just inside the quiet zone: the corner finder pattern's dark ring.
        XCTAssertEqual(value(x: quiet + 1, y: quiet + 1), 0)
    }

    func testNothingOrTooMuchToEncodeIsRefused() {
        XCTAssertNil(QRCode.image(for: "   \n\t"))
        XCTAssertNil(QRCode.payload(for: ""))
        // Byte mode at level M holds 2,331 bytes in the largest code.
        XCTAssertNotNil(QRCode.image(for: String(repeating: "a", count: 2331)))
        XCTAssertNil(QRCode.image(for: String(repeating: "a", count: 2332)))
    }

    func testModuleSizeAimsForAReadableImage() {
        XCTAssertEqual(QRCode.moduleSize(forModules: 29), 22)     // smallest code: 638 px
        XCTAssertEqual(QRCode.moduleSize(forModules: 185), 3)     // largest code: 555 px
        XCTAssertEqual(QRCode.moduleSize(forModules: 400), 3)     // never below 3 px a module
    }

    // MARK: - Reading

    func testCodesAreReadTopToBottomLeftToRightOnce() {
        let codes: [(payload: String?, box: CGRect)] = [
            ("right", CGRect(x: 0.6, y: 0.6, width: 0.2, height: 0.2)),      // top row (maxY 0.80)
            ("bottom", CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)),
            ("left", CGRect(x: 0.1, y: 0.605, width: 0.2, height: 0.2)),     // same row, a touch higher
            (nil, CGRect(x: 0.4, y: 0.4, width: 0.1, height: 0.1)),          // found, not decodable as text
            ("right", CGRect(x: 0.6, y: 0.6, width: 0.2, height: 0.2)),      // reported twice
            ("  ", CGRect(x: 0.4, y: 0.2, width: 0.1, height: 0.1)),
        ]
        XCTAssertEqual(ScreenTextTool.orderedPayloads(codes), ["left", "right", "bottom"])
    }

    func testEachRowCopiesWhatItPromises() {
        // Copy Text: text wins; a bare code is the fallback, not a beep.
        XCTAssertEqual(ScreenTextTool.clipboardText(reading: .text, text: "Total $42", codes: ["https://x"]), "Total $42")
        XCTAssertEqual(ScreenTextTool.clipboardText(reading: .text, text: "", codes: ["a", "b"]), "a\nb")
        XCTAssertNil(ScreenTextTool.clipboardText(reading: .text, text: "", codes: []))
        // Scan QR Code: only ever code contents.
        XCTAssertEqual(ScreenTextTool.clipboardText(reading: .codes, text: "", codes: ["https://x"]), "https://x")
        XCTAssertNil(ScreenTextTool.clipboardText(reading: .codes, text: "Scan me", codes: []))
    }
}
