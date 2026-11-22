import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// An image format the shelf can save to. HEIC is offered only where
/// ImageIO can actually write it (`CGImageDestinationCopyTypeIdentifiers`);
/// on a Mac without the encoder the menu simply has two entries.
enum ShelfImageFormat: String, CaseIterable {
    case jpeg, png, heic

    var type: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        }
    }

    var title: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        }
    }

    /// Lossy formats only; nil leaves PNG lossless.
    var quality: Double? {
        switch self {
        case .jpeg: return 0.85
        case .heic: return 0.8
        case .png: return nil
        }
    }

    /// Pure, unit-tested.
    static func available(destinationTypes: [String]) -> [ShelfImageFormat] {
        allCases.filter { destinationTypes.contains($0.type.identifier) }
    }

    static var supported: [ShelfImageFormat] {
        available(destinationTypes: (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
    }
}

/// Resize presets, by the longest side in pixels.
enum ShelfResize: Int, CaseIterable {
    case original = 0
    case px3840 = 3840
    case px2560 = 2560
    case px1920 = 1920
    case px1280 = 1280
    case px640 = 640

    var title: String {
        self == .original ? "Original Size" : "Longest Side \(rawValue) px"
    }

    /// Pure, unit-tested. The longest side to scale to, or nil to keep the
    /// size. Never enlarges: a 1000 px image asked for 1920 stays 1000.
    func targetLongestSide(width: Int, height: Int) -> Int? {
        guard self != .original, max(width, height) > rawValue else { return nil }
        return rawValue
    }
}

enum ShelfConvertError: Error {
    case unreadable, encodeFailed, locked, empty
}

/// Output naming and writing. Never overwrites: a name already taken gets
/// " 2", " 3"… the way Finder does it, and the write itself refuses to
/// replace a file that appeared in the meantime.
enum ShelfOutput {
    /// The real ~/Downloads. Inside the sandbox the system hands back the
    /// container's `Downloads`, a symlink to it; resolving it means a path
    /// that "Show in Finder" and other apps see as the user's own folder.
    static func downloadsDirectory() -> URL? {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.resolvingSymlinksInPath()
    }

    /// Pure, unit-tested.
    static func candidateName(_ preferred: String, attempt: Int) -> String {
        guard attempt > 1 else { return preferred }
        let ext = (preferred as NSString).pathExtension
        let base = ext.isEmpty ? preferred : (preferred as NSString).deletingPathExtension
        return ext.isEmpty ? "\(base) \(attempt)" : "\(base) \(attempt).\(ext)"
    }

    /// Pure, unit-tested.
    static func uniqueName(_ preferred: String, exists: (String) -> Bool) -> String {
        var attempt = 1
        while exists(candidateName(preferred, attempt: attempt)) { attempt += 1 }
        return candidateName(preferred, attempt: attempt)
    }

    /// Pure, unit-tested. "IMG_0042.HEIC" at 1920 → "IMG_0042 1920px.jpg".
    static func convertedName(source: String, longestSide: Int?, fileExtension: String) -> String {
        let base = (source as NSString).deletingPathExtension
        let size = longestSide.map { " \($0)px" } ?? ""
        return "\(base.isEmpty ? "Image" : base)\(size).\(fileExtension)"
    }

    /// Pure, unit-tested. "Report.pdf" and two more → "Report + 2 more.pdf".
    static func mergedName(first: String, count: Int) -> String {
        let base = (first as NSString).deletingPathExtension
        let name = base.isEmpty ? "Merged" : base
        return count > 1 ? "\(name) + \(count - 1) more.pdf" : "\(name).pdf"
    }

    /// Pure, unit-tested. The line the shelf shows after a conversion.
    static func resultMessage(saved: Int, failed: Int) -> String {
        let files = saved == 1 ? "1 file" : "\(saved) files"
        if failed == 0 { return "Saved \(files) to Downloads" }
        if saved == 0 { return failed == 1 ? "Couldn’t convert that file" : "Couldn’t convert those \(failed) files" }
        return "Saved \(files) to Downloads — \(failed) couldn’t be converted"
    }

    /// Writes `data` under the first free variant of `preferredName`.
    /// `.withoutOverwriting` makes the existence check and the create one
    /// step, so a file that appears between the two is still never replaced.
    static func write(_ data: Data, preferredName: String, in directory: URL) throws -> URL {
        for attempt in 1...9_999 {
            let url = directory.appendingPathComponent(candidateName(preferredName, attempt: attempt))
            do {
                try data.write(to: url, options: .withoutOverwriting)
                return url
            } catch {
                // Taken: try the next name. Anything else is a real failure.
                if FileManager.default.fileExists(atPath: url.path) { continue }
                throw error
            }
        }
        throw CocoaError(.fileWriteFileExists)
    }
}

/// Image conversion with ImageIO. The first frame only — an animated GIF or
/// a multi-page TIFF becomes one still.
enum ShelfImageConverter {
    /// Converts one image into `directory` and returns the new file's URL.
    /// Safe off the main thread.
    static func convert(_ source: URL, to format: ShelfImageFormat, resize: ShelfResize,
                        stripMetadata: Bool, into directory: URL) throws -> URL {
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(imageSource) > 0 else { throw ShelfConvertError.unreadable }
        let properties = (CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]) ?? [:]
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        guard width > 0, height > 0 else { throw ShelfConvertError.unreadable }

        // The thumbnail call does the scaling *and* applies the EXIF
        // orientation to the pixels — necessary, because stripping metadata
        // drops the orientation tag and a phone photo would turn sideways.
        // At "Original Size" it decodes at full resolution.
        let target = resize.targetLongestSide(width: width, height: height)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: target ?? max(width, height),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard var image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw ShelfConvertError.unreadable
        }
        if needsFlatten(format: format, alphaInfo: image.alphaInfo), let flat = flattened(image) {
            image = flat
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, format.type.identifier as CFString, 1, nil) else {
            throw ShelfConvertError.encodeFailed
        }
        CGImageDestinationAddImage(destination, image,
                                   outputProperties(source: properties, stripMetadata: stripMetadata,
                                                    quality: format.quality) as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ShelfConvertError.encodeFailed }

        let name = ShelfOutput.convertedName(source: source.lastPathComponent, longestSide: target,
                                             fileExtension: format.fileExtension)
        return try ShelfOutput.write(data as Data, preferredName: name, in: directory)
    }

    /// Pure, unit-tested. What to write alongside the pixels.
    ///
    /// Stripped: nothing but the compression quality — no EXIF, GPS, IPTC or
    /// TIFF fields (the colour profile stays, it lives in the image's colour
    /// space). Kept: those four dictionaries, with the orientation reset to
    /// "up" because the pixels are already upright, and the EXIF pixel size
    /// dropped because it described the original. XMP-only metadata is not
    /// carried either way.
    static func outputProperties(source: [CFString: Any], stripMetadata: Bool, quality: Double?) -> [CFString: Any] {
        var output: [CFString: Any] = [:]
        if !stripMetadata {
            for key in [kCGImagePropertyExifDictionary, kCGImagePropertyGPSDictionary,
                        kCGImagePropertyIPTCDictionary, kCGImagePropertyTIFFDictionary] {
                if let value = source[key] { output[key] = value }
            }
            output[kCGImagePropertyOrientation] = 1
            if var tiff = output[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                tiff[kCGImagePropertyTIFFOrientation] = 1
                output[kCGImagePropertyTIFFDictionary] = tiff
            }
            if var exif = output[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                exif.removeValue(forKey: kCGImagePropertyExifPixelXDimension)
                exif.removeValue(forKey: kCGImagePropertyExifPixelYDimension)
                output[kCGImagePropertyExifDictionary] = exif
            }
        }
        if let quality { output[kCGImageDestinationLossyCompressionQuality] = quality }
        return output
    }

    /// Pure, unit-tested. JPEG has no alpha; written as-is, transparent areas
    /// come out as whatever colour sits under them (usually black). Those
    /// images are put on white first.
    static func needsFlatten(format: ShelfImageFormat, alphaInfo: CGImageAlphaInfo) -> Bool {
        guard format == .jpeg else { return false }
        switch alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: return true
        }
    }

    private static func flattened(_ image: CGImage) -> CGImage? {
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let spaces = [image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil },
                      CGColorSpace(name: CGColorSpace.sRGB)].compactMap { $0 }
        for space in spaces {
            guard let context = CGContext(data: nil, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { continue }
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(rect)
            context.draw(image, in: rect)
            return context.makeImage()
        }
        return nil
    }
}

/// PDF merging with PDFKit. Safe off the main thread (no view involved).
enum ShelfPDFMerger {
    /// Merges `sources` in the order given — the shelf passes them in shelf
    /// order — into one new PDF in `directory`. A password-locked PDF stops
    /// the merge rather than being silently left out.
    static func merge(_ sources: [URL], into directory: URL) throws -> URL {
        guard let first = sources.first else { throw ShelfConvertError.empty }
        let merged = PDFDocument()
        for url in sources {
            guard let document = PDFDocument(url: url) else { throw ShelfConvertError.unreadable }
            guard !document.isLocked else { throw ShelfConvertError.locked }
            for index in 0..<document.pageCount {
                // A page belongs to one document; insert a copy.
                guard let page = document.page(at: index)?.copy() as? PDFPage else { continue }
                merged.insert(page, at: merged.pageCount)
            }
        }
        guard merged.pageCount > 0, let data = merged.dataRepresentation() else { throw ShelfConvertError.empty }
        return try ShelfOutput.write(data, preferredName: ShelfOutput.mergedName(first: first.lastPathComponent, count: sources.count),
                                     in: directory)
    }
}
