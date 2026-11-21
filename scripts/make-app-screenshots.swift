// Composes the App Store screenshots from the menu captures made by
// scripts/make-app-screenshots.sh. Run through that script, or directly:
//
//   swift scripts/make-app-screenshots.swift <raw-dir> <out-dir>
//
// Output: 2880x1800 PNGs (a size the Mac App Store accepts), each a caption on
// the left and real captured menus on the right. The menus are never redrawn —
// only placed and scaled — so what the store shows is what the app shows.
import AppKit

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: make-app-screenshots.swift <raw-dir> <out-dir>\n".data(using: .utf8)!)
    exit(2)
}
let rawDir = URL(fileURLWithPath: args[1]), outDir = URL(fileURLWithPath: args[2])
let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

let canvas = NSSize(width: 2880, height: 1800)
// Must match MenuBarController.screenshotBackdrop: the captures carry that
// colour around the menu, so they sit on the canvas with no visible edge.
let background = NSColor(srgbRed: 0.047, green: 0.063, blue: 0.086, alpha: 1)

struct Layer {
    let file: String      // capture name, without .png
    let scale: CGFloat    // of its pixel size
    let centre: CGPoint   // on the canvas, origin bottom-left
    var alpha: CGFloat = 1
}

struct Shot {
    let name: String
    let headline: String
    let body: String
    let layers: [Layer]
}

// The full menu, dimmed, stands behind an open submenu to show where it lives.
// Kept clear of the submenu beside it: each capture is a rectangle of backdrop
// around its menu, and where two overlap the front one would cut a visible
// notch out of the one behind.
let menuBehind = Layer(file: "main", scale: 0.98, centre: CGPoint(x: 1640, y: 900), alpha: 0.38)

let shots: [Shot] = [
    Shot(name: "1-toolbox",
         headline: "17 Mac tools.\nOne menu-bar icon.",
         body: "Eight are free. Pro adds window snapping, a clipboard manager, hidden menu bar icons and an XDR brightness boost.",
         layers: [Layer(file: "main", scale: 1.06, centre: CGPoint(x: 2200, y: 900))]),
    Shot(name: "2-window-snapping",
         headline: "Snap windows\ninto place.",
         body: "Halves, quarters, maximize and centre — from the menu, or with ⌃⌥ and the arrow keys.",
         layers: [menuBehind, Layer(file: "WindowSnapTool", scale: 1.55, centre: CGPoint(x: 2420, y: 900))]),
    Shot(name: "3-clipboard",
         headline: "Fix copied text\nin one click.",
         body: "Change case, trim, sort lines, encode and decode, format JSON, hash. Plus a searchable history of what you copied.",
         layers: [menuBehind, Layer(file: "ClipboardTool", scale: 1.3, centre: CGPoint(x: 2420, y: 900))]),
    Shot(name: "4-generate-and-clocks",
         headline: "The small things,\nalready there.",
         body: "A UUID, a strong password or a timestamp straight to your clipboard. The time in the cities you work with.",
         layers: [menuBehind,
                  Layer(file: "GeneratorTool", scale: 1.5, centre: CGPoint(x: 2420, y: 1160)),
                  Layer(file: "WorldClockTool", scale: 1.5, centre: CGPoint(x: 2420, y: 600))]),
    Shot(name: "5-keep-awake",
         headline: "Keep your Mac\nawake.",
         body: "For half an hour, a few hours, or until you say so. Presentations, downloads, long reads.",
         layers: [menuBehind, Layer(file: "KeepAwakeTool", scale: 1.7, centre: CGPoint(x: 2420, y: 900))]),
]

func capture(_ name: String) -> NSBitmapImageRep? {
    guard let data = try? Data(contentsOf: rawDir.appendingPathComponent("\(name).png")) else { return nil }
    return NSBitmapImageRep(data: data)
}

/// Refuse a capture whose corner is not the backdrop colour: that would mean
/// the backdrop was not up and the picture contains part of someone's desktop.
func isOnBackdrop(_ rep: NSBitmapImageRep) -> Bool {
    guard let corner = rep.colorAt(x: 2, y: 2)?.usingColorSpace(.sRGB),
          let want = background.usingColorSpace(.sRGB) else { return false }
    return abs(corner.redComponent - want.redComponent) < 0.03
        && abs(corner.greenComponent - want.greenComponent) < 0.03
        && abs(corner.blueComponent - want.blueComponent) < 0.03
}

let brand = NSImage(contentsOf: repoRoot.appendingPathComponent("assets/brand/MaxCandela_Logo.png"))
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

for shot in shots {
    // An explicit bitmap so the file is exactly 2880x1800 pixels whatever the
    // scale factor of the display this happens to run on.
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width), pixelsHigh: Int(canvas.height),
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: rep) else { continue }
    rep.size = canvas
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    background.setFill()
    NSRect(origin: .zero, size: canvas).fill()

    var complete = true
    for layer in shot.layers {
        guard let image = capture(layer.file), isOnBackdrop(image) else {
            FileHandle.standardError.write("skipping \(shot.name): capture '\(layer.file)' is missing or not on the backdrop\n".data(using: .utf8)!)
            complete = false
            break
        }
        let size = NSSize(width: CGFloat(image.pixelsWide) * layer.scale, height: CGFloat(image.pixelsHigh) * layer.scale)
        image.draw(in: NSRect(x: layer.centre.x - size.width / 2, y: layer.centre.y - size.height / 2,
                              width: size.width, height: size.height),
                   from: .zero, operation: .sourceOver, fraction: layer.alpha, respectFlipped: false, hints: nil)
    }

    let left: CGFloat = 190
    if let brand {
        brand.draw(in: NSRect(x: left, y: 1490, width: 104, height: 104))
    }
    ("MaxCandela" as NSString).draw(at: NSPoint(x: left + 132, y: 1506), withAttributes: [
        .font: NSFont.systemFont(ofSize: 56, weight: .semibold),
        .foregroundColor: NSColor(white: 0.93, alpha: 1),
    ])

    let headlineStyle = NSMutableParagraphStyle()
    headlineStyle.lineHeightMultiple = 0.94
    let headline = NSAttributedString(string: shot.headline, attributes: [
        .font: NSFont.systemFont(ofSize: 136, weight: .bold),
        .foregroundColor: NSColor.white,
        .kern: -4.5,
        .paragraphStyle: headlineStyle,
    ])
    let bodyStyle = NSMutableParagraphStyle()
    bodyStyle.lineHeightMultiple = 1.18
    let body = NSAttributedString(string: shot.body, attributes: [
        .font: NSFont.systemFont(ofSize: 58, weight: .regular),
        .foregroundColor: NSColor(srgbRed: 0.62, green: 0.66, blue: 0.70, alpha: 1),
        .paragraphStyle: bodyStyle,
    ])
    // A lone menu on the right leaves the headline more room than a menu
    // with a submenu beside it does.
    let column: CGFloat = shot.layers.count == 1 ? 1500 : 1090
    let headlineBox = headline.boundingRect(with: NSSize(width: column, height: 2000), options: [.usesLineFragmentOrigin])
    let bodyBox = body.boundingRect(with: NSSize(width: 1080, height: 2000), options: [.usesLineFragmentOrigin])
    // The two blocks, 56 px apart, centred on the canvas a little below the
    // brand row.
    let total = headlineBox.height + 56 + bodyBox.height
    let top = (canvas.height - 120) / 2 + total / 2
    headline.draw(with: NSRect(x: left, y: top - headlineBox.height, width: column, height: headlineBox.height),
                  options: [.usesLineFragmentOrigin])
    body.draw(with: NSRect(x: left + 4, y: top - total, width: 1080, height: bodyBox.height),
              options: [.usesLineFragmentOrigin])

    NSGraphicsContext.restoreGraphicsState()
    guard complete, let drawn = rep.cgImage else { continue }
    // App Store Connect refuses screenshots that carry an alpha channel, even
    // a fully opaque one, so flatten into an RGB-only bitmap before encoding.
    guard let flat = CGContext(data: nil, width: drawn.width, height: drawn.height, bitsPerComponent: 8,
                               bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                               bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { continue }
    flat.draw(drawn, in: CGRect(x: 0, y: 0, width: drawn.width, height: drawn.height))
    let url = outDir.appendingPathComponent("\(shot.name).png")
    guard let opaque = flat.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { continue }
    CGImageDestinationAddImage(destination, opaque, nil)
    guard CGImageDestinationFinalize(destination) else { continue }
    print("wrote \(url.lastPathComponent)")
}
