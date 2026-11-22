import CoreImage

/// Text → a QR code image, with Core Image's built-in generator. Used by
/// Generate ▸ QR Code from Clipboard. On-device; nothing is looked up.
enum QRCode {
    /// What gets encoded: the text without surrounding whitespace (a URL
    /// copied from a terminal often drags a newline along, and some scanners
    /// then refuse the link). Nil when nothing is left.
    static func payload(for text: String) -> Data? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Data(trimmed.utf8)
    }

    /// The generator's output carries one module of white border; the QR
    /// specification asks for four, and a code pasted onto a dark slide
    /// without them may not scan. Measured 2026-11-22: a version-1 code
    /// (21 modules) comes out 23 wide.
    static let generatorBorder = 1
    static let quietZone = 4

    /// Pixels per module for a code `modules` wide including its quiet zone:
    /// whole pixels (crisp edges), aiming at roughly 640 px overall, never
    /// below 3.
    static func moduleSize(forModules modules: Int) -> Int {
        max(3, 640 / max(modules, 1))
    }

    /// Software rendering: the image is a few hundred pixels, and this keeps
    /// the GPU out of a menu click.
    private static let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])

    /// A black-on-white QR code for `text` at error-correction level M (the
    /// common default: survives ~15% damage). Nil when there is nothing to
    /// encode or it is too long for any QR code — about 2,300 bytes of
    /// ordinary text; the generator itself decides, since the limit depends
    /// on whether the text is digits, capitals or anything else.
    static func image(for text: String) -> CGImage? {
        guard let payload = payload(for: text),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(payload, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage,
              let raw = context.createCGImage(output, from: output.extent) else { return nil }

        let extra = quietZone - generatorBorder
        let modules = raw.width + 2 * extra
        let size = moduleSize(forModules: modules)
        let side = modules * size
        guard let canvas = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                                     bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                                     bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        canvas.setFillColor(CGColor(gray: 1, alpha: 1))
        canvas.fill(CGRect(x: 0, y: 0, width: side, height: side))
        canvas.interpolationQuality = .none
        canvas.draw(raw, in: CGRect(x: extra * size, y: extra * size,
                                    width: raw.width * size, height: raw.height * size))
        return canvas.makeImage()
    }
}
