#!/usr/bin/env swift
// Generates the MaxCandela app icon: the brand mark — a MacBook silhouette
// with a blazing golden starburst on its screen — on a dark rounded tile.
// Same visual language as scripts/make-hero.swift, composed for a square.
// Usage: swift scripts/make-icon.swift <output.iconset>
// Then:  iconutil -c icns <output.iconset> -o AppIcon.icns

import AppKit

guard CommandLine.arguments.count == 2 else {
    print("usage: make-icon.swift <output.iconset>")
    exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let bgTop = rgba(0x1a, 0x1f, 0x2e)
let bgBottom = rgba(0x0a, 0x0d, 0x14)
let shellTop = rgba(0x3a, 0x42, 0x4d)
let shellBottom = rgba(0x20, 0x26, 0x2e)
let displayColor = rgba(0x04, 0x05, 0x07)
let amber = rgba(0xff, 0xb0, 0x2e)
let amberLight = rgba(0xff, 0xd4, 0x79)
let coreWhite = rgba(0xff, 0xf3, 0xd9)

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    let s = CGFloat(pixels)
    // Design in y-down coordinates; flip once here.
    cg.translateBy(x: 0, y: s)
    cg.scaleBy(x: 1, y: -1)

    // macOS icon grid: content inset ~10% with a continuous-corner tile.
    let inset = s * 0.10
    let tileRect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let tile = NSBezierPath(roundedRect: tileRect, xRadius: tileRect.width * 0.225,
                            yRadius: tileRect.width * 0.225)
    NSGradient(colors: [bgTop, bgBottom])!.draw(in: tile, angle: -90)

    cg.saveGState()
    tile.addClip()

    // --- Laptop ---
    let shellRect = NSRect(x: s * 0.19, y: s * 0.24, width: s * 0.62, height: s * 0.40)
    let shell = NSBezierPath(roundedRect: shellRect, xRadius: s * 0.035, yRadius: s * 0.035)
    NSGradient(colors: [shellTop, shellBottom])!.draw(in: shell, angle: -90)

    let displayRect = shellRect.insetBy(dx: s * 0.018, dy: s * 0.018)
    let display = NSBezierPath(roundedRect: displayRect, xRadius: s * 0.02, yRadius: s * 0.02)
    displayColor.setFill()
    display.fill()

    // Notch: flat top flush with the display edge, rounded bottom corners.
    cg.saveGState()
    display.addClip()
    shellBottom.setFill()
    NSBezierPath(roundedRect: NSRect(x: s * 0.465, y: displayRect.minY - s * 0.015,
                                     width: s * 0.07, height: s * 0.036),
                 xRadius: s * 0.010, yRadius: s * 0.010).fill()
    cg.restoreGState()

    // --- Starburst, clipped to display, additive light ---
    cg.saveGState()
    display.addClip()
    cg.setBlendMode(.plusLighter)

    let core = CGPoint(x: s * 0.5, y: displayRect.maxY - s * 0.03)

    func radialGlow(radius: CGFloat, color: NSColor, alpha: CGFloat) {
        NSGradient(colors: [color.withAlphaComponent(alpha),
                            color.withAlphaComponent(0)])!
            .draw(fromCenter: NSPoint(x: core.x, y: core.y), radius: 0,
                  toCenter: NSPoint(x: core.x, y: core.y), radius: radius, options: [])
    }
    radialGlow(radius: s * 0.24, color: amber, alpha: 0.40)
    radialGlow(radius: s * 0.12, color: amberLight, alpha: 0.60)
    radialGlow(radius: s * 0.05, color: coreWhite, alpha: 0.90)

    let rays: [(CGFloat, CGFloat)] = [
        (0, 0.335), (-18, 0.285), (18, 0.285), (-42, 0.26), (42, 0.26), (-72, 0.22), (72, 0.22),
    ]
    func ray(angleDeg: CGFloat, length: CGFloat, width: CGFloat, color: NSColor, alpha: CGFloat) {
        let a = angleDeg * .pi / 180
        let dir = CGPoint(x: sin(a), y: -cos(a))
        let perp = CGPoint(x: cos(a), y: sin(a))
        let tip = CGPoint(x: core.x + dir.x * length, y: core.y + dir.y * length)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: core.x - perp.x * width / 2, y: core.y - perp.y * width / 2))
        path.line(to: NSPoint(x: tip.x, y: tip.y))
        path.line(to: NSPoint(x: core.x + perp.x * width / 2, y: core.y + perp.y * width / 2))
        path.close()
        color.withAlphaComponent(alpha).setFill()
        path.fill()
    }
    for (angle, length) in rays {
        ray(angleDeg: angle, length: length * s, width: s * 0.030, color: amber, alpha: 0.16)
        ray(angleDeg: angle, length: length * s * 0.99, width: s * 0.015, color: amber, alpha: 0.45)
        ray(angleDeg: angle, length: length * s * 0.97, width: s * 0.0075, color: amberLight, alpha: 0.95)
    }
    coreWhite.setFill()
    NSBezierPath(ovalIn: NSRect(x: core.x - s * 0.012, y: core.y - s * 0.012,
                                width: s * 0.024, height: s * 0.024)).fill()
    cg.restoreGState()

    // --- Base deck with front lip notch ---
    let baseRect = NSRect(x: s * 0.13, y: shellRect.maxY, width: s * 0.74, height: s * 0.030)
    let base = NSBezierPath(roundedRect: baseRect, xRadius: baseRect.height / 2,
                            yRadius: baseRect.height / 2)
    NSGradient(colors: [shellTop, shellBottom])!.draw(in: base, angle: -90)
    displayColor.setFill()
    NSBezierPath(roundedRect: NSRect(x: s * 0.465, y: baseRect.minY,
                                     width: s * 0.07, height: s * 0.012),
                 xRadius: s * 0.006, yRadius: s * 0.006).fill()

    cg.restoreGState()   // tile clip
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// Every size/scale pair the iconset format wants.
let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for entry in entries {
    let rep = drawIcon(pixels: entry.pixels)
    let png = rep.representation(using: .png, properties: [:])!
    try png.write(to: outDir.appendingPathComponent("\(entry.name).png"))
}
print("Wrote \(entries.count) images to \(outDir.path)")
