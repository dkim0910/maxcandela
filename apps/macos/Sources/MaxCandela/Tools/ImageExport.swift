import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Getting an image out of the app: PNG data, the clipboard, a file name.
/// Shared by the screenshot editor and the QR code generator.
enum ImageExport {

    /// PNG with the resolution recorded (144 DPI for a Retina capture), so
    /// Preview, Pages and Keynote place it at the size it was on screen
    /// instead of doubling it — the same thing macOS's own screenshots do.
    static func pngData(_ image: CGImage, pixelsPerPoint: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        let dpi = 72 * max(pixelsPerPoint, 1)
        let properties = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// Puts the image on the clipboard as PNG and TIFF. PNG is what browsers
    /// and chat apps take; TIFF is what older Cocoa apps look for first.
    /// Returns false if it could not be encoded (the clipboard is then left
    /// as it was).
    @discardableResult
    static func copy(_ image: CGImage, pixelsPerPoint: CGFloat,
                     to pasteboard: NSPasteboard = .general) -> Bool {
        guard let png = pngData(image, pixelsPerPoint: pixelsPerPoint) else { return false }
        let rep = NSBitmapImageRep(cgImage: image)
        rep.size = NSSize(width: CGFloat(image.width) / max(pixelsPerPoint, 1),
                          height: CGFloat(image.height) / max(pixelsPerPoint, 1))
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
        if let tiff = rep.tiffRepresentation { pasteboard.setData(tiff, forType: .tiff) }
        return true
    }

    /// "Screenshot 2026-11-22 at 16.05.12.png" — macOS's own pattern, with
    /// dots for the time because Finder shows a ":" in a name as "/".
    static func fileName(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Screenshot \(formatter.string(from: date)).png"
    }
}
